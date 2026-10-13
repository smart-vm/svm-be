module PaymentTestHelper
  # Records requests and replays canned [status, body] responses.
  class FakeTransport
    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def call(method, url, headers: {}, body: nil)
      @requests << { method: method, url: url, headers: headers, body: body }
      response = @responses.shift || raise("FakeTransport: no response queued for #{method} #{url}")
      raise response if response.is_a?(Exception)

      response
    end
  end

  def notification(transaction, status: :success, amount: transaction.amount_in_rupiah)
    Payments::Notification.new(
      external_id: transaction.uuid, gateway_id: "gw-#{transaction.id}", status: status, amount: BigDecimal(amount.to_s),
      fee: BigDecimal("525.0"), rrn: "000133655495", issuer_name: "BCA", paid_at: Time.current,
      raw: { "external_id" => transaction.uuid, "status" => status.to_s }
    )
  end

  def kiosk_headers(machine = machines(:one))
    { "Authorization" => "Bearer #{machine.api_token}" }
  end
end
