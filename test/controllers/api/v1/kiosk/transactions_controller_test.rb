require "test_helper"

class Api::V1::Kiosk::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @machine = machines(:one)
    @slot = slots(:one)
  end

  test "rejects requests without a valid machine token" do
    post api_v1_kiosk_transactions_url, params: { slot_id: @slot.id }, as: :json
    assert_response :unauthorized

    post api_v1_kiosk_transactions_url, params: { slot_id: @slot.id }, headers: { "Authorization" => "Bearer nope" }, as: :json
    assert_response :unauthorized
  end

  test "the full sale: create, pay, claim, vend" do
    post api_v1_kiosk_transactions_url, params: { slot_id: @slot.id, payment_method: "qris" }, headers: kiosk_headers, as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal "pending", body["status"]
    assert_equal 15_000, body["amount"]
    assert_equal @slot.slot_number, body["slot_number"]
    assert body["checkout_url"].present?
    assert_operator body["expires_in"], :>, 0

    transaction = Transaction.find_by!(uuid: body["uuid"])

    # Claiming before payment is refused.
    post claim_api_v1_kiosk_transaction_url(transaction.uuid), headers: kiosk_headers, as: :json
    assert_response :conflict

    raw, signature = Payments::MockGateway.new.build_callback(transaction, status: "success")
    Payments::WebhookReceiver.call(raw_body: raw, signature: signature)

    get api_v1_kiosk_transaction_url(transaction.uuid), headers: kiosk_headers, as: :json
    assert_equal "paid", response.parsed_body["status"]

    post claim_api_v1_kiosk_transaction_url(transaction.uuid), headers: kiosk_headers, as: :json
    assert_response :success
    assert_equal "dispensing", response.parsed_body["status"]

    post claim_api_v1_kiosk_transaction_url(transaction.uuid), headers: kiosk_headers, as: :json
    assert_response :conflict

    post vend_result_api_v1_kiosk_transaction_url(transaction.uuid),
         params: { outcome: "success", raw_code: 1, duration_ms: 9100, message: "dispensed" }, headers: kiosk_headers, as: :json
    assert_response :success
    assert_equal "settled", response.parsed_body["status"]
    assert_equal 4, @slot.reload.current_stock

    # A retried report is acknowledged.
    post vend_result_api_v1_kiosk_transaction_url(transaction.uuid), params: { outcome: "success" }, headers: kiosk_headers, as: :json
    assert_response :success
  end

  test "a machine cannot see another machine's transaction" do
    get api_v1_kiosk_transaction_url(transactions(:two).uuid), headers: kiosk_headers, as: :json
    assert_response :not_found
  end

  test "create validates the slot" do
    post api_v1_kiosk_transactions_url, params: { slot_id: slots(:two).id }, headers: kiosk_headers, as: :json
    assert_response :not_found

    @slot.update!(current_stock: 0)
    post api_v1_kiosk_transactions_url, params: { slot_id: @slot.id }, headers: kiosk_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "slot is out of stock", response.parsed_body["error"]
  end

  test "cancel checks the gateway first and keeps a payment that already landed" do
    transaction = transactions(:one)
    Payments.gateway = gateway = Payments::MockGateway.new
    def gateway.fetch_status(external_id)
      Payments::Notification.new(external_id: external_id, gateway_id: "gw", status: :success, amount: BigDecimal("15000"),
                                 fee: nil, rrn: nil, issuer_name: nil, paid_at: Time.current, raw: {})
    end

    post cancel_api_v1_kiosk_transaction_url(transaction.uuid), headers: kiosk_headers, as: :json

    assert_response :success
    assert_equal "paid", response.parsed_body["status"]
  ensure
    Payments.gateway = nil
  end

  test "cancel without payment cancels" do
    post cancel_api_v1_kiosk_transaction_url(transactions(:one).uuid), headers: kiosk_headers, as: :json

    assert_equal "cancelled", response.parsed_body["status"]
  end

  test "vend_result validates the outcome" do
    post vend_result_api_v1_kiosk_transaction_url(transactions(:one).uuid), params: { outcome: "maybe" }, headers: kiosk_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "catalog lists the machine's stocked slots" do
    get api_v1_kiosk_catalog_url, headers: kiosk_headers, as: :json

    assert_response :success
    assert_equal @machine.uuid, response.parsed_body.dig("machine", "uuid")
    item = response.parsed_body["items"].sole
    assert_equal({ "slot_id" => @slot.id, "price" => 15_000, "stock" => 5 }, item.slice("slot_id", "price", "stock"))
  end
end
