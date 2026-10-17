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

  test "status and search filters combine and can be cleared" do
    sign_in users(:one)
    matching = transactions(:one)
    matching.update!(status: "needs_review")
    get transactions_url, params: { status: "needs_review", q: matching.uuid }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /#{matching.uuid.split('-').first}/
    assert_select "a", text: "Clear filters"

    get transactions_url, params: { q: "nonexistent-location" }
    assert_select "td", text: /No transactions match these filters/
  end

  test "pagination provides access beyond the old 100 row cutoff" do
    sign_in users(:one)
    101.times do |index|
      Transaction.create!(machine: machines(:one), slot: slots(:one), amount: 15000, created_at: index.minutes.ago)
    end
    get transactions_url, params: { page: 3 }
    assert_response :success
    assert_select "tbody tr", count: 3
    assert_select "nav[aria-label='Transaction pages']", text: /Page 3 of 3/
    assert_select "a[rel=prev]", count: 1
    assert_select "a[rel=next]", count: 0
  end

  test "CSV exports only the selected results and escapes spreadsheet formulas" do
    sign_in users(:one)
    transaction = transactions(:one)
    transaction.machine.update!(location_name: "=1+1")
    get transactions_url(format: :csv), params: { q: transaction.uuid }
    assert_response :success
    assert_includes response.media_type, "text/csv"
    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.length
    assert_equal transaction.uuid, rows.first["Transaction ID"]
    assert_equal "'=1+1", rows.first["Location"]

    transaction.update_column(:amount, nil)
    get transactions_url(format: :csv), params: { q: transaction.uuid }
    assert_response :success
    assert_nil CSV.parse(response.body, headers: true).first["Amount (IDR)"]
  end

  test "resolution errors remain visible after redirect" do
    sign_in users(:one)
    patch resolve_transaction_url(transactions(:one), outcome: "refunded")
    follow_redirect!
    assert_select "[role=alert]", text: /already pending/
    assert_select "[data-controller=modal]", count: 0
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
