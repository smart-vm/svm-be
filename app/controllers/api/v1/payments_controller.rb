class Api::V1::PaymentsController < ApplicationController
  # Skip CSRF check since this request originates from an external API provider
  skip_before_action :verify_authenticity_token

  def webhook
    transaction = Transaction.find_by(uuid: params[:transaction_uuid])

    if transaction && params[:event] == 'payment.succeeded'
      # 1. Update the accounting ledger state safely
      transaction.update!(
        status: 'paid', 
        external_reference: params[:external_reference]
      )

      # 2. Instantly broadcast a drop token down the open WebSocket channel to the Flutter app
      ActionCable.server.broadcast(
        "machine_transaction_channel_#{transaction.machine.uuid}",
        {
          event: 'dispense_authorized',
          transaction_uuid: transaction.uuid,
          slot_number: transaction.slot.slot_number
        }
      )

      render json: { status: 'success', message: 'Dispense token transmitted' }, status: :ok
    else
      render json: { status: 'error', message: 'Transaction mismatch or invalid state' }, status: :bad_request
    end
  end
end