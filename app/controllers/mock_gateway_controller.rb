# Hosted checkout page for Payments::MockGateway. Paying here sends a signed
# callback through the same receiver the real webhook uses.
class MockGatewayController < ActionController::Base
  layout false

  before_action { head :not_found unless Payments.mock? }
  before_action :set_transaction

  def show
  end

  def complete
    status = params[:result] == "failed" ? "failed" : "success"
    raw_body, signature = Payments.gateway.build_callback(@transaction, status: status)
    Payments::WebhookReceiver.call(raw_body: raw_body, signature: signature)

    redirect_to mock_gateway_checkout_path(@transaction.uuid)
  end

  private

  def set_transaction
    @transaction = Transaction.includes(:machine, slot: :product).find_by!(uuid: params[:uuid])
  end
end
