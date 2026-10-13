require "test_helper"

class MockGatewayControllerTest < ActionDispatch::IntegrationTest
  test "paying on the mock checkout page goes through the webhook path" do
    transaction = transactions(:one)

    get mock_gateway_checkout_url(transaction.uuid)
    assert_response :success
    assert_match "Rp 15.000", response.body

    post mock_gateway_checkout_complete_url(transaction.uuid, result: "success")

    assert_redirected_to mock_gateway_checkout_url(transaction.uuid)
    assert transaction.reload.paid?
  end
end
