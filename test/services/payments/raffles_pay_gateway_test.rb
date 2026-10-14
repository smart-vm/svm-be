require "test_helper"

class Payments::RafflesPayGatewayTest < ActiveSupport::TestCase
  setup do
    @our_key = OpenSSL::PKey::RSA.new(2048)
    @their_key = OpenSSL::PKey::RSA.new(2048)
    @transaction = transactions(:one)
    @transaction.update!(payment_method: "qris")
  end

  def gateway(transport)
    Payments::RafflesPayGateway.new(
      base_url: "https://rafflespay.test/", api_version: "v2", client_id: "cid", client_secret: "secret",
      private_key_pem: @our_key.private_to_pem, gateway_public_key_pem: @their_key.public_to_pem,
      callback_url: "https://svm.test/api/v1/payments/webhook", transport: transport
    )
  end

  def success_body(overrides = {})
    {
      success: true, code: "success", error: nil,
      data: {
        id: "39b03a61-28a1-432a-97d9-67c941cce201", external_id: @transaction.uuid, amount: "15000.0",
        payment_method: "qris", payment_channel: nil, redirect_url: nil, qris_redirect_url: "https://swipelune.test/q",
        qris_image_url: nil, qris_image_content: nil, callback_url: "https://svm.test/api/v1/payments/webhook",
        checkout_url: "https://swipelune.test/checkout/abc"
      }.merge(overrides)
    }.to_json
  end

  test "create_charge sends the exact signed canonical body with basic auth" do
    transport = FakeTransport.new([ 200, success_body ])

    charge = gateway(transport).create_charge(@transaction)

    request = transport.requests.first
    assert_equal :post, request[:method]
    assert_equal "https://rafflespay.test/api/v2/payments", request[:url]
    assert_equal "Basic #{Base64.strict_encode64('cid:secret')}", request[:headers]["Authorization"]
    expected = %({"amount":15000,"callback_url":"https://svm.test/api/v1/payments/webhook","external_id":"#{@transaction.uuid}","payment_method":"qris"})
    assert_equal expected, request[:body]
    assert Payments::Signer.valid?(request[:body], request[:headers]["X-Signature"], @our_key.public_to_pem)

    assert_equal "39b03a61-28a1-432a-97d9-67c941cce201", charge.gateway_id
    assert_equal "https://swipelune.test/checkout/abc", charge.checkout_url
  end

  test "emoney includes the channel and prefers the provider redirect" do
    @transaction.update!(payment_method: "emoney", payment_channel: "ovo")
    transport = FakeTransport.new([ 200, success_body(payment_method: "emoney", redirect_url: "https://ovo.test/pay") ])

    charge = gateway(transport).create_charge(@transaction)

    assert_includes transport.requests.first[:body], %("payment_channel":"ovo")
    assert_equal "https://ovo.test/pay", charge.checkout_url
  end

  test "only a real QRIS payload is used as qr content" do
    charge = gateway(FakeTransport.new([ 200, success_body(qris_image_content: "00020101021226...6304ABCD") ])).create_charge(@transaction)
    assert_equal "00020101021226...6304ABCD", charge.qr_content

    charge = gateway(FakeTransport.new([ 200, success_body(qris_image_content: "iVBORw0KGgo=") ])).create_charge(@transaction)
    assert_nil charge.qr_content
  end

  test "an amount that comes back different is an error" do
    error = assert_raises(Payments::GatewayError) do
      gateway(FakeTransport.new([ 200, success_body(amount: "1500000.0") ])).create_charge(@transaction)
    end
    assert_match "amount mismatch", error.message
  end

  test "4xx is a rejected request, 5xx a gateway error" do
    rejected = { success: false, code: "failed", error: { message: "payment_channel must be blank" } }.to_json

    error = assert_raises(Payments::RequestRejected) { gateway(FakeTransport.new([ 400, rejected ])).create_charge(@transaction) }
    assert_match "payment_channel must be blank", error.message

    assert_raises(Payments::GatewayError) { gateway(FakeTransport.new([ 502, "Bad Gateway" ])).create_charge(@transaction) }
  end

  test "verify_webhook! accepts their signature over the canonical body" do
    raw = %({"id":"x","external_id":"#{@transaction.uuid}","status":"success","amount":15000,"fee":525.0,"rrn":"1","paid_at":"2026-07-26T10:22:31Z","issuer_name":"BCA"})
    signature = Payments::Signer.sign(Payments::Signer.canonical_json_js(JSON.parse(raw)), @their_key.private_to_pem)

    notification = gateway(FakeTransport.new).verify_webhook!(raw, signature)

    assert_equal :success, notification.status
    assert_equal @transaction.uuid, notification.external_id
    assert_equal BigDecimal("15000"), notification.amount
    assert_equal BigDecimal("525"), notification.fee
  end

  test "verify_webhook! rejects our own key and missing signatures" do
    raw = %({"external_id":"#{@transaction.uuid}","status":"success","amount":15000})

    assert_raises(Payments::InvalidSignature) { gateway(FakeTransport.new).verify_webhook!(raw, Payments::Signer.sign(raw, @our_key.private_to_pem)) }
    assert_raises(Payments::InvalidSignature) { gateway(FakeTransport.new).verify_webhook!(raw, nil) }
  end

  test "fetch_status reads data, maps unknown statuses to pending, and returns nil on 404" do
    body = { success: true, data: { external_id: @transaction.uuid, amount: 15000, status: "processing" }, status: "ignored" }.to_json
    transport = FakeTransport.new([ 200, body ], [ 404, { success: false, error: { message: "payment not found" } }.to_json ])

    assert_equal :pending, gateway(transport).fetch_status(@transaction.uuid).status
    assert_equal "https://rafflespay.test/api/v2/payments/#{@transaction.uuid}", transport.requests.first[:url]
    assert_nil transport.requests.first[:headers]["X-Signature"]
    assert_nil gateway(transport).fetch_status(@transaction.uuid)
  end

  test "settings are trimmed so a stray space never reaches the signed body" do
    ENV["APP_BASE_URL"] = "https://kiosk.example.com \n"
    assert_equal "https://kiosk.example.com/api/v1/payments/webhook", Payments.callback_url
  ensure
    ENV.delete("APP_BASE_URL")
  end
end
