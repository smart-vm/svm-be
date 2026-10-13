require "test_helper"

class Api::V1::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = transactions(:one)
    @gateway = Payments::MockGateway.new
  end

  def post_callback(raw, signature)
    post api_v1_payments_webhook_url, params: raw,
         headers: { "Content-Type" => "application/json; charset=utf-8", "X-Signature" => signature }
  end

  test "a signed success callback marks the transaction paid" do
    raw, signature = @gateway.build_callback(@transaction, status: "success")

    post_callback(raw, signature)

    assert_response :success
    assert @transaction.reload.paid?
    assert_equal "MOCK BANK", @transaction.issuer_name
    assert_equal @transaction.uuid, @transaction.callback_payload["external_id"]
  end

  test "duplicate deliveries are acknowledged and change nothing" do
    raw, signature = @gateway.build_callback(@transaction, status: "success")
    post_callback(raw, signature)
    @transaction.reload.claim_dispense!

    post_callback(raw, signature)

    assert_response :success
    assert @transaction.reload.dispensing?
  end

  test "a bad signature is rejected" do
    raw, _signature = @gateway.build_callback(@transaction, status: "success")

    post_callback(raw, "forged")

    assert_response :unauthorized
    assert @transaction.reload.pending?
  end

  test "an unknown external_id is a 404 so the gateway retries" do
    @transaction.uuid = SecureRandom.uuid
    raw, signature = @gateway.build_callback(@transaction, status: "success")

    post_callback(raw, signature)

    assert_response :not_found
  end
end
