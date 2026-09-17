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
end
