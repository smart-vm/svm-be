class Transaction < ApplicationRecord
  # pending          waiting for the customer to pay
  # paid             gateway confirmed payment; the kiosk may claim the dispense
  # dispensing       the kiosk claimed it and is turning the motor
  # settled          product dropped (the only state that counts as revenue)
  # failed           payment failed or could not be created; no money taken
  # expired          nobody paid before expires_at
  # cancelled        the customer cancelled on the kiosk
  # refund_required  money was taken but nothing was dispensed
  # needs_review     the motor may have turned but there is no confirmed result
  # refunded         an operator refunded the customer by hand
  STATUSES = %w[pending paid dispensing settled failed expired cancelled refund_required needs_review refunded].freeze

  # Outcomes reported by the kiosk, straight from the VMC SDK's VendOutcome.
  VEND_OUTCOMES = %w[success failed timeout unknown aborted].freeze

  PAYMENT_METHODS = %w[qris emoney].freeze
  PAYMENT_CHANNELS = %w[ovo dana linkaja gopay shopeepay].freeze

  belongs_to :machine
  belongs_to :slot

  enum :status, STATUSES.index_with(&:itself)

  validates :status, inclusion: { in: STATUSES }
  validates :uuid, presence: true, uniqueness: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true
  validates :payment_channel, inclusion: { in: PAYMENT_CHANNELS }, allow_nil: true

  before_validation :set_defaults, on: :create

  # IDR has no minor units: the gateway takes whole rupiah as an integer.
  def amount_in_rupiah
    raise ArgumentError, "amount #{amount} is not a whole rupiah value" unless amount && amount.frac.zero?

    amount.to_i
  end

  # --- Payment ------------------------------------------------------------

  # Idempotent: duplicate callbacks for an already-paid transaction are no-ops.
  def apply_payment_success!(notification)
    changed = with_lock do
      attrs = payment_attributes(notification)

      if pending? && notification.amount != amount_in_rupiah
        Rails.logger.error("[payments] amount mismatch on #{uuid}: expected #{amount_in_rupiah}, got #{notification.amount}")
        update!(attrs.merge(status: "refund_required", failure_reason: "amount_mismatch"))
      elsif pending?
        update!(attrs.merge(status: "paid", paid_at: notification.paid_at || Time.current))
      elsif expired? || cancelled? || failed?
        # The customer paid after we gave up on them. Money is in, nothing will drop.
        Rails.logger.error("[payments] late payment on #{status} transaction #{uuid}")
        update!(attrs.merge(status: "refund_required", failure_reason: "paid_after_#{status}", paid_at: notification.paid_at || Time.current))
      else
        next false
      end
      true
    end

    broadcast_update if changed
    changed
  end

  def apply_payment_failure!(notification)
    changed = with_lock do
      next false unless pending?

      update!(payment_attributes(notification).merge(status: "failed", failure_reason: "payment_failed"))
      true
    end

    broadcast_update if changed
    changed
  end

  def expire!
    transition!(from: :pending, to: "expired", failure_reason: "payment_timeout")
  end

  def cancel!
    transition!(from: :pending, to: "cancelled", failure_reason: "cancelled_by_customer")
  end

  # --- Dispensing ---------------------------------------------------------

  # Exactly one caller wins: the kiosk may get the paid event over the socket
  # and from polling, but only the first claim may turn the motor.
  def claim_dispense!
    transition!(from: :paid, to: "dispensing", dispense_started_at: Time.current)
  end

  def record_vend_result!(outcome, details = {})
    raise ArgumentError, "unknown vend outcome #{outcome.inspect}" unless VEND_OUTCOMES.include?(outcome)

    changed = with_lock do
      # A late report may still land after the sweeper gave up waiting.
      next false unless dispensing? || (needs_review? && failure_reason == "no_vend_result")

      result = details.to_h.merge("outcome" => outcome, "reported_at" => Time.current.iso8601)

      case outcome
      when "success"
        update!(status: "settled", vend_result: result, dispensed_at: Time.current, failure_reason: nil)
        slot.consume_stock_for_sale!(at: dispensed_at)
      when "failed", "aborted", "timeout"
        # The board confirmed nothing dropped (or the motor never ran).
        update!(status: "refund_required", vend_result: result, failure_reason: "vend_#{outcome}")
      else
        # UNKNOWN: the motor command was accepted but no result came back.
        # Never auto-refund this one; someone has to look at the slot.
        update!(status: "needs_review", vend_result: result, failure_reason: "vend_unknown")
      end
      true
    end

    broadcast_update if changed
    changed
  end

  def mark_unclaimed!
    transition!(from: :paid, to: "refund_required", failure_reason: "dispense_not_claimed")
  end

  def mark_stuck!
    transition!(from: :dispensing, to: "needs_review", failure_reason: "no_vend_result")
  end

  # --- Back office --------------------------------------------------------

  def resolvable?
    refund_required? || needs_review?
  end

  def resolve!(outcome)
    raise ArgumentError, "unknown resolution #{outcome.inspect}" unless %w[refunded settled].include?(outcome)

    with_lock do
      next false unless resolvable?

      if outcome == "settled"
        # The product reached the customer, so the old failure no longer applies.
        # The board's original report stays in vend_result.
        update!(status: "settled", dispensed_at: dispensed_at || Time.current, failure_reason: nil)
        slot.consume_stock_for_sale!(at: dispensed_at)
      else
        update!(status: "refunded")
      end
      true
    end
  end

  # --- Kiosk --------------------------------------------------------------

  def as_kiosk_json
    {
      uuid: uuid,
      status: status,
      amount: amount.to_i,
      slot_id: slot_id,
      slot_number: slot.slot_number,
      product_name: slot.product&.name,
      payment_method: payment_method,
      checkout_url: checkout_url,
      qr_content: qr_content,
      qr_image_url: qr_image_url,
      expires_at: expires_at&.iso8601,
      # Seconds left, so the kiosk's countdown doesn't depend on its own clock.
      expires_in: expires_at ? [ (expires_at - Time.current).ceil, 0 ].max : nil,
      paid_at: paid_at&.iso8601,
      failure_reason: failure_reason
    }
  end

  def broadcast_update
    machine.broadcast_to_kiosk(event: "transaction_updated", transaction: as_kiosk_json)
  end

  private

  def transition!(from:, to:, **attrs)
    changed = with_lock do
      next false unless status == from.to_s

      update!(attrs.merge(status: to))
      true
    end

    broadcast_update if changed
    changed
  end

  def payment_attributes(notification)
    {
      external_reference: notification.gateway_id.presence || external_reference,
      callback_payload: notification.raw,
      fee: notification.fee,
      rrn: notification.rrn,
      issuer_name: notification.issuer_name
    }
  end

  def set_defaults
    self.status ||= "pending"
    self.uuid ||= SecureRandom.uuid
  end
end
