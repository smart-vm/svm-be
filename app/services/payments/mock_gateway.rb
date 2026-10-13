module Payments
  # Stand-in for RafflesPay during development and tests. It has the same
  # interface and the same moving parts: a hosted checkout page
  # (MockGatewayController) and a signed callback that goes through the real
  # webhook code path. Signatures are HMAC instead of RSA.
  class MockGateway
    def create_charge(transaction)
      gateway_id = "mock_#{SecureRandom.hex(8)}"
      Charge.new(
        gateway_id: gateway_id,
        checkout_url: "#{Payments.app_base_url.chomp('/')}/mock_gateway/checkouts/#{transaction.uuid}",
        qr_content: nil,
        qr_image_url: nil,
        raw: { "id" => gateway_id, "external_id" => transaction.uuid, "amount" => "#{transaction.amount_in_rupiah}.0" }
      )
    end

    # Builds and signs the body RafflesPay would POST to the callback URL.
    # Returns [raw_body, signature].
    def build_callback(transaction, status:)
      body = {
        "id" => transaction.external_reference,
        "merchant_id" => 0,
        "external_id" => transaction.uuid,
        "status" => status,
        "amount" => transaction.amount_in_rupiah,
        "fee" => (transaction.amount_in_rupiah * 0.035).round(2),
        "percentage_fee" => 3.5,
        "rrn" => format("%012d", SecureRandom.random_number(10**12)),
        "created_at" => transaction.created_at.utc.iso8601,
        "paid_at" => (Time.current.utc.iso8601 if status == "success"),
        "issuer_name" => "MOCK BANK",
        "issuer_id" => nil
      }
      Rails.cache.write(cache_key(transaction.uuid), body, expires_in: 1.day)

      raw = JSON.generate(body)
      [ raw, sign(raw) ]
    end

    def verify_webhook!(raw_body, signature)
      unless signature.present? && ActiveSupport::SecurityUtils.secure_compare(sign(raw_body), signature.to_s)
        raise InvalidSignature, "signature did not verify"
      end

      notification_from(JSON.parse(raw_body))
    end

    def fetch_status(external_id)
      body = Rails.cache.read(cache_key(external_id))
      body && notification_from(body)
    end

    private

    def sign(raw)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("mock_payment_gateway"), raw)
    end

    def cache_key(external_id) = "mock_gateway/payments/#{external_id}"

    def notification_from(data)
      Notification.new(
        external_id: data["external_id"],
        gateway_id: data["id"],
        status: { "success" => :success, "failed" => :failed }.fetch(data["status"], :pending),
        amount: BigDecimal(data["amount"].to_s),
        fee: data["fee"] && BigDecimal(data["fee"].to_s),
        rrn: data["rrn"],
        issuer_name: data["issuer_name"],
        paid_at: data["paid_at"].present? ? Time.zone.parse(data["paid_at"]) : nil,
        raw: data
      )
    end
  end
end
