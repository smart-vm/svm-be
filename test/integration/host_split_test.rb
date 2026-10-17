require "test_helper"

class HostSplitTest < ActionDispatch::IntegrationTest
  setup do
    Rails.configuration.x.api_host = "api.vendoravm.com"
    Rails.configuration.x.cms_host = "cms.vendoravm.com"
  end

  teardown do
    Rails.configuration.x.api_host = nil
    Rails.configuration.x.cms_host = nil
  end

  test "the API host serves the kiosk API and webhook but not the back office" do
    host! "api.vendoravm.com"

    get api_v1_kiosk_catalog_path, headers: kiosk_headers
    assert_response :success

    post api_v1_payments_webhook_path, params: "{}", headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized # reached the controller; signature missing

    get new_user_session_path
    assert_response :not_found
    get root_path
    assert_response :not_found
  end

  test "the CMS host serves the back office but not the API" do
    host! "cms.vendoravm.com"

    get new_user_session_path
    assert_response :success

    get api_v1_kiosk_catalog_path, headers: kiosk_headers
    assert_response :not_found
    post api_v1_payments_webhook_path, params: "{}", headers: { "Content-Type" => "application/json" }
    assert_response :not_found
  end

  test "other hosts (local development, the bare server IP) still serve everything" do
    host! "178.128.50.161"

    get new_user_session_path
    assert_response :success
    get api_v1_kiosk_catalog_path, headers: kiosk_headers
    assert_response :success
  end
end
