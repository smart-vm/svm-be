# Runs every minute (config/recurring.yml). RafflesPay has no "expired"
# status and callbacks can go missing, so this job owns both.
class TransactionSweepJob < ApplicationJob
  queue_as :default

  RECONCILE_AFTER = 1.minute
  # A paid sale the kiosk never picked up (offline, crashed, customer left).
  UNCLAIMED_AFTER = 2.minutes
  # vend_timeout_ms is 30 s on the board; anything this old has lost its report.
  STUCK_AFTER = 5.minutes

  def perform
    Transaction.pending.where(created_at: ..RECONCILE_AFTER.ago).find_each do |transaction|
      Payments::Reconciler.call(transaction)
    rescue Payments::Error => e
      Rails.logger.warn("[payments] reconcile failed for #{transaction.uuid}: #{e.message}")
    end

    Transaction.pending.where(expires_at: ..Time.current).find_each(&:expire!)
    # updated_at is set by the transition into paid / dispensing.
    Transaction.paid.where(updated_at: ..UNCLAIMED_AFTER.ago).find_each(&:mark_unclaimed!)
    Transaction.dispensing.where(updated_at: ..STUCK_AFTER.ago).find_each(&:mark_stuck!)
  end
end
