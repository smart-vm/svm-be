# Payment gateway boundary. Everything outside this namespace talks to
# `Payments.gateway`, which is either the RafflesPay adapter or a local mock
# that behaves the same way (hosted checkout page + signed callback).
module Payments
  class Error < StandardError; end
  # Unexpected response, network failure or a 5xx: the gateway may recover.
  class GatewayError < Error; end
  # 4xx: the gateway refused the request before contacting any provider.
  class RequestRejected < GatewayError; end
  class InvalidSignature < Error; end
  class ConfigurationError < Error; end

  # What a gateway returns after creating a payment.
  Charge = Data.define(:gateway_id, :checkout_url, :qr_content, :qr_image_url, :raw)

  # A verified callback or a status lookup, normalised across gateways.
  # status is :success, :failed or :pending.
  Notification = Data.define(:external_id, :gateway_id, :status, :amount, :fee, :rrn, :issuer_name, :paid_at, :raw)

  class << self
    attr_writer :gateway

    def gateway
      @gateway ||= build_gateway
    end

    def gateway_name
      ENV.fetch("PAYMENT_GATEWAY") { Rails.env.production? ? "raffles_pay" : "mock" }
    end

    def mock?
      gateway_name == "mock"
    end

    def expires_in
      ENV.fetch("PAYMENT_EXPIRES_IN", 180).to_i.seconds
    end

    # Public base URL of this app; RafflesPay must reach it over HTTPS.
    def app_base_url
      ENV.fetch("APP_BASE_URL") do
        raise ConfigurationError, "APP_BASE_URL is required in production" if Rails.env.production?

        "http://localhost:3000"
      end
    end

    def callback_url
      "#{app_base_url.chomp('/')}/api/v1/payments/webhook"
    end

    private

    def build_gateway
      case gateway_name
      when "mock" then MockGateway.new
      when "raffles_pay" then RafflesPayGateway.from_env
      else raise ConfigurationError, "unknown PAYMENT_GATEWAY #{gateway_name.inspect}"
      end
    end
  end
end
