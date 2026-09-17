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
end
