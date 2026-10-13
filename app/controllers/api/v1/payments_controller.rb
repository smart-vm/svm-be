# RafflesPay callback. Verifies the signature, applies the result and answers
# fast; duplicates are expected (they retry up to 8 times) and are no-ops.
class Api::V1::PaymentsController < ActionController::API
  def webhook
    result = Payments::WebhookReceiver.call(raw_body: request.raw_post, signature: request.headers["X-Signature"])

    if result == :not_found
      render json: { success: false, error: "unknown external_id" }, status: :not_found
    else
      render json: { success: true }, status: :ok
    end
  rescue Payments::InvalidSignature => e
    Rails.logger.warn("[payments] rejected callback: #{e.message}")
    render json: { success: false, error: "invalid signature" }, status: :unauthorized
  rescue JSON::ParserError
    render json: { success: false, error: "invalid body" }, status: :bad_request
  end
end
