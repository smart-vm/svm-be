require "test_helper"

class Api::V1::PaymentsControllerTest < ActionDispatch::IntegrationTest
  test "should process successful payment webhook via POST" do
    # 1. Grab a transaction from your updated transactions.yml fixture
    transaction = transactions(:one)

    # 2. Simulate the payment gateway sending a POST request with JSON
    post api_v1_payments_webhook_url, params: {
      event: "payment.succeeded",
      external_reference: "TEST-WEBHOOK-999",
      transaction_uuid: transaction.uuid
    }, as: :json

    # 3. Assert that the server responds with a 200 OK (success)
    assert_response :success

    # 4. (Bonus) Verify the database actually updated the status
    transaction.reload
    assert_equal "paid", transaction.status
  end

  test "should reject invalid webhook data" do
    # Simulate a POST request with a fake UUID
    post api_v1_payments_webhook_url, params: {
      event: "payment.succeeded",
      transaction_uuid: "fake-uuid-that-does-not-exist"
    }, as: :json

    # Assert that the server catches it and returns a 400 Bad Request
    assert_response :bad_request
  end
end
