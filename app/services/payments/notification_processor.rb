module Payments
  # Applies a verified callback or status lookup to our transaction.
  # Idempotent: duplicates and replays leave a final state untouched.
  class NotificationProcessor
    def self.call(notification)
      transaction = Transaction.find_by(uuid: notification.external_id)
      unless transaction
        Rails.logger.warn("[payments] notification for unknown external_id #{notification.external_id.inspect}")
        return :not_found
      end

      case notification.status
      when :success then transaction.apply_payment_success!(notification)
      when :failed then transaction.apply_payment_failure!(notification)
      end

      :ok
    end
  end
end
