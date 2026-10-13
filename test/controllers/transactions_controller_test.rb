require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to sign in when not authenticated" do
    get transactions_url
    assert_redirected_to new_user_session_path
  end

  test "should get index when authenticated" do
    sign_in users(:one)

    get transactions_url
    assert_response :success
  end

  test "index lists transactions ordered by most recent first" do
    sign_in users(:one)
    newer, older = transactions(:one), transactions(:two)
    newer.update!(created_at: 1.day.from_now)
    older.update!(created_at: 2.days.ago)

    get transactions_url

    assert_response :success
    body = response.body
    assert body.index(newer.uuid.split("-").first) < body.index(older.uuid.split("-").first)
  end

  test "resolve marks a refund as done and shows the action only when needed" do
    sign_in users(:one)
    transaction = transactions(:one)
    transaction.update!(status: "refund_required", failure_reason: "vend_failed")

    get transactions_url
    assert_match "Mark refunded", response.body

    patch resolve_transaction_url(transaction, outcome: "refunded")

    assert_redirected_to transactions_path
    assert transaction.reload.refunded?
  end

  test "resolve refuses a transaction that is not waiting on the back office" do
    sign_in users(:one)

    patch resolve_transaction_url(transactions(:one), outcome: "refunded")

    assert transactions(:one).reload.pending?
  end
end
