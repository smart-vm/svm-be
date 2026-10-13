require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "defaults status to pending and generates a uuid on create" do
    transaction = Transaction.create!(machine: machines(:one), slot: slots(:one), amount: 15_000)

    assert transaction.pending?
    assert transaction.uuid.present?
  end

  test "rejects a status outside the allowed enum values" do
    assert_raises(ArgumentError) do
      Transaction.new(machine: machines(:one), slot: slots(:one), amount: 1, status: "bogus")
    end
  end

  test "can transition through the enum statuses" do
    transaction = Transaction.create!(machine: machines(:one), slot: slots(:one), amount: 1)

    transaction.settled!
    assert transaction.settled?

    transaction.paid!
    assert transaction.paid?
  end

  test "uuid must be unique" do
    duplicate = Transaction.new(
      machine: machines(:one), slot: slots(:one), amount: 1, uuid: transactions(:one).uuid
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uuid], "has already been taken"
  end
end

class TransactionStateMachineTest < ActiveSupport::TestCase
  setup do
    @transaction = transactions(:one)
  end

  test "amount_in_rupiah refuses fractional amounts" do
    assert_equal 15_000, @transaction.amount_in_rupiah
    @transaction.amount = 9.99
    assert_raises(ArgumentError) { @transaction.amount_in_rupiah }
  end

  test "a successful payment marks it paid once and broadcasts to the kiosk" do
    stream = @transaction.machine.transaction_stream

    assert_broadcasts(stream, 1) do
      assert @transaction.apply_payment_success!(notification(@transaction))
      assert_not @transaction.apply_payment_success!(notification(@transaction))
    end

    assert @transaction.reload.paid?
    assert_equal "000133655495", @transaction.rrn
    assert_equal BigDecimal("525"), @transaction.fee
  end

  test "an amount mismatch is never treated as paid" do
    @transaction.apply_payment_success!(notification(@transaction, amount: 1_500))

    assert @transaction.reload.refund_required?
    assert_equal "amount_mismatch", @transaction.failure_reason
  end

  test "a payment after expiry needs a refund" do
    @transaction.expire!
    @transaction.apply_payment_success!(notification(@transaction))

    assert @transaction.reload.refund_required?
    assert_equal "paid_after_expired", @transaction.failure_reason
  end

  test "a failed payment only moves a pending transaction" do
    assert @transaction.apply_payment_failure!(notification(@transaction, status: :failed))
    assert @transaction.reload.failed?

    @transaction.update!(status: "paid")
    assert_not @transaction.apply_payment_failure!(notification(@transaction, status: :failed))
    assert @transaction.reload.paid?
  end

  test "only one dispense claim succeeds" do
    @transaction.update!(status: "paid")

    assert @transaction.claim_dispense!
    assert_not @transaction.claim_dispense!
    assert @transaction.reload.dispensing?
  end

  test "a successful vend settles and takes one item out of stock" do
    @transaction.update!(status: "dispensing")

    assert_difference -> { @transaction.slot.reload.current_stock }, -1 do
      assert @transaction.record_vend_result!("success", "duration_ms" => "9000")
    end
    assert @transaction.reload.settled?
    assert_equal "success", @transaction.vend_result["outcome"]
  end

  test "vend outcomes map to the SDK's money rules" do
    { "failed" => "refund_required", "aborted" => "refund_required", "timeout" => "refund_required",
      "unknown" => "needs_review" }.each do |outcome, expected|
      @transaction.update!(status: "dispensing", vend_result: {})

      assert_no_difference -> { @transaction.slot.reload.current_stock } do
        @transaction.record_vend_result!(outcome)
      end
      assert_equal expected, @transaction.reload.status, "outcome #{outcome}"
    end
  end

  test "vend results are ignored unless the transaction is dispensing" do
    assert_not @transaction.record_vend_result!("success")
    assert @transaction.reload.pending?
  end

  test "a late vend report still lands after the sweeper flagged it" do
    @transaction.update!(status: "dispensing", dispense_started_at: 10.minutes.ago)
    @transaction.mark_stuck!

    assert @transaction.record_vend_result!("success")
    assert @transaction.reload.settled?
  end

  test "back office can resolve refunds and reviews" do
    @transaction.update!(status: "needs_review")
    assert_difference -> { @transaction.slot.reload.current_stock }, -1 do
      assert @transaction.resolve!("settled")
    end

    @transaction.update!(status: "refund_required")
    assert @transaction.resolve!("refunded")
    assert @transaction.reload.refunded?
    assert_not @transaction.resolve!("refunded")
  end
end
