module Payments
  # Asks the gateway directly. Covers missed callbacks, and it's the only way
  # a payment completes locally, since the gateway can't reach localhost.
  class Reconciler
    def self.call(transaction, gateway: Payments.gateway)
      notification = gateway.fetch_status(transaction.uuid)
      return :not_found unless notification

      NotificationProcessor.call(notification)
    end
  end
end
