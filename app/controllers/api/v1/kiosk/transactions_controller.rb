# The kiosk side of a sale:
#
#   POST create        -> pending, returns the QR / checkout URL
#   (customer pays; webhook or reconcile moves it to paid; pushed over the cable)
#   POST claim         -> dispensing; only one claim ever succeeds
#   POST vend_result   -> settled / refund_required / needs_review
#
# GET show is the polling fallback for when the socket is down.
class Api::V1::Kiosk::TransactionsController < Api::V1::Kiosk::BaseController
  before_action :set_transaction, except: :create

  def create
    slot = current_machine.slots.find_by(id: params[:slot_id])
    return render json: { error: "slot not found" }, status: :not_found unless slot

    transaction = Payments::StartCheckout.call(
      machine: current_machine,
      slot: slot,
      payment_method: params[:payment_method],
      payment_channel: params[:payment_channel]
    )
    render json: transaction.as_kiosk_json, status: :created
  rescue Payments::StartCheckout::Invalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Payments::GatewayError => e
    Rails.logger.error("[payments] create charge failed: #{e.message}")
    render json: { error: "payment gateway unavailable" }, status: :bad_gateway
  end

  def show
    render json: @transaction.as_kiosk_json
  end

  # Customer pressed cancel, or the countdown ran out. Ask the gateway first:
  # the callback may simply not have arrived yet.
  def cancel
    if @transaction.pending?
      begin
        Payments::Reconciler.call(@transaction)
      rescue Payments::Error => e
        Rails.logger.warn("[payments] reconcile before cancel failed for #{@transaction.uuid}: #{e.message}")
      end
      @transaction.reload.cancel!
    end

    render json: @transaction.reload.as_kiosk_json
  end

  def claim
    if @transaction.claim_dispense!
      render json: @transaction.as_kiosk_json
    else
      render json: @transaction.reload.as_kiosk_json.merge(error: "transaction is #{@transaction.status}, not paid"), status: :conflict
    end
  end

  def vend_result
    outcome = params[:outcome].to_s
    unless Transaction::VEND_OUTCOMES.include?(outcome)
      return render json: { error: "outcome must be one of #{Transaction::VEND_OUTCOMES.join(', ')}" }, status: :unprocessable_entity
    end

    details = params.permit(:reason, :raw_code, :flags, :message, :duration_ms).to_h

    if @transaction.record_vend_result!(outcome, details)
      render json: @transaction.as_kiosk_json
    elsif @transaction.reload.vend_result["outcome"] == outcome
      # Retried report that already landed.
      render json: @transaction.as_kiosk_json
    else
      render json: @transaction.as_kiosk_json.merge(error: "transaction is #{@transaction.status}, not dispensing"), status: :conflict
    end
  end

  private

  def set_transaction
    @transaction = current_machine.transactions.includes(slot: :product).find_by(uuid: params[:uuid])
    render json: { error: "transaction not found" }, status: :not_found unless @transaction
  end
end
