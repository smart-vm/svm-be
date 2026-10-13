module Payments
  # Creates a transaction for one slot and the matching gateway payment.
  class StartCheckout
    class Invalid < Error; end

    def self.call(...) = new(...).call

    def initialize(machine:, slot:, payment_method: "qris", payment_channel: nil, gateway: Payments.gateway)
      @machine = machine
      @slot = slot
      @payment_method = payment_method.presence || "qris"
      @payment_channel = @payment_method == "emoney" ? payment_channel.presence : nil
      @gateway = gateway
    end

    def call
      validate!

      # One customer at a time per machine: a new checkout replaces any QR
      # still on screen. A late payment on it becomes refund_required.
      @machine.transactions.pending.find_each(&:cancel!)

      transaction = @machine.transactions.create!(
        slot: @slot,
        amount: @slot.product.price,
        payment_method: @payment_method,
        payment_channel: @payment_channel,
        expires_at: Payments.expires_in.from_now
      )

      begin
        charge = @gateway.create_charge(transaction)
      rescue Payments::GatewayError => e
        transaction.update!(status: "failed", failure_reason: "gateway_error: #{e.message}".truncate(250))
        raise
      end

      transaction.update!(
        external_reference: charge.gateway_id,
        checkout_url: charge.checkout_url,
        qr_content: charge.qr_content,
        qr_image_url: charge.qr_image_url,
        gateway_payload: charge.raw
      )
      transaction
    end

    private

    def validate!
      raise Invalid, "machine is not active" unless @machine.status == "active"
      raise Invalid, "slot does not belong to this machine" unless @slot.machine_id == @machine.id
      raise Invalid, "slot has no product" unless @slot.product
      raise Invalid, "slot is out of stock" unless @slot.current_stock.to_i.positive?

      price = @slot.product.price
      raise Invalid, "product has no price" unless price&.positive?
      raise Invalid, "price must be whole rupiah" unless price.frac.zero?
      raise Invalid, "unsupported payment method" unless Transaction::PAYMENT_METHODS.include?(@payment_method)
      if @payment_method == "emoney" && !Transaction::PAYMENT_CHANNELS.include?(@payment_channel)
        raise Invalid, "payment_channel is required for emoney"
      end
      raise Invalid, "machine is busy dispensing" if busy?
    end

    # A sale in flight. Stale ones are the sweeper's to clean up, not a reason
    # to lock the machine.
    def busy?
      @machine.transactions.paid.where(updated_at: TransactionSweepJob::UNCLAIMED_AFTER.ago..).exists? ||
        @machine.transactions.dispensing.where(updated_at: TransactionSweepJob::STUCK_AFTER.ago..).exists?
    end
  end
end
