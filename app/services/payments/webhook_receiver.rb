module Payments
  # Verify, then apply. Kept separate from the controller so the mock checkout
  # page exercises the exact same path as a real callback.
  class WebhookReceiver
    def self.call(raw_body:, signature:, gateway: Payments.gateway)
      notification = gateway.verify_webhook!(raw_body, signature)
      NotificationProcessor.call(notification)
    end
  end
end
