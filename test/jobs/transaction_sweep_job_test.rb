require "test_helper"

class TransactionSweepJobTest < ActiveJob::TestCase
  test "expires unpaid transactions past their deadline" do
    transaction = transactions(:one)
    transaction.update!(expires_at: 1.second.ago)

    TransactionSweepJob.perform_now

    assert transaction.reload.expired?
  end

  test "reconciles a payment whose callback never arrived" do
    transaction = transactions(:one)
    transaction.update!(created_at: 2.minutes.ago, expires_at: 1.minute.from_now)

    with_cache(ActiveSupport::Cache::MemoryStore.new) do
      Payments::MockGateway.new.build_callback(transaction, status: "success")
      TransactionSweepJob.perform_now
    end

    assert transaction.reload.paid?
  end

  test "flags paid sales nobody claimed and dispenses that never reported" do
    unclaimed = transactions(:one)
    unclaimed.update!(status: "paid", paid_at: nil, updated_at: 3.minutes.ago)
    stuck = transactions(:two)
    stuck.update!(status: "dispensing", updated_at: 6.minutes.ago)

    TransactionSweepJob.perform_now

    assert unclaimed.reload.refund_required?
    assert_equal "dispense_not_claimed", unclaimed.failure_reason
    assert stuck.reload.needs_review?
  end

  private

  def with_cache(store)
    original = Rails.cache
    Rails.cache = store
    yield
  ensure
    Rails.cache = original
  end
end
