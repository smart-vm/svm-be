require "test_helper"

class Api::V1::PaymentsControllerTest < ActionDispatch::IntegrationTest
  test "should get webhook" do
    get api_v1_payments_webhook_url
    assert_response :success
  end
end
