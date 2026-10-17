require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to sign in when not authenticated" do
    get root_url
    assert_redirected_to new_user_session_path
  end

  test "should get index when authenticated" do
    sign_in users(:one)

    get root_url
    assert_response :success
  end

  test "index reports the current machine count" do
    sign_in users(:one)

    get root_url
    assert_select "h3", text: Machine.count.to_s
  end

  test "dashboard uses the signed in identity and real values" do
    sign_in users(:one)
    transactions(:one).update!(status: "settled", amount: 12345, created_at: Time.current)
    get root_url
    assert_select "header", text: /#{Regexp.escape(users(:one).email)}/
    assert_select "h3", text: "Rp 12.345"
    assert_no_match "2% more than yesterday", response.body
    assert_no_match "Sultan Alta", response.body
    assert_select "nav[aria-label='Main navigation'] a[aria-current=page]", text: "Overview"
    assert_select "aside#erp-sidebar nav a", count: 5
  end
end
