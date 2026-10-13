module Payments
  # RafflesPay (Indonesia): hosted checkout, QRIS + e-wallets, IDR only.
  #
  # Requests are signed SHA256withRSA over canonical JSON, and the exact signed
  # bytes are sent as the body. Callbacks are verified with RafflesPay's public
  # key ("RPAY Public Key" in their dashboard), not ours.
  class RafflesPayGateway
    # QRIS payloads (EMVCo) always start with this; anything else in
    # qris_image_content is probably an image, not a string to encode.
    QRIS_PAYLOAD_PREFIX = "000201".freeze

    def self.from_env(transport: HttpTransport.new)
      new(
        base_url: ENV.fetch("RAFFLESPAY_BASE_URL", "https://rafflespay.com"),
        api_version: ENV.fetch("RAFFLESPAY_API_VERSION", "v1"),
        client_id: fetch_env("RAFFLESPAY_CLIENT_ID"),
        client_secret: fetch_env("RAFFLESPAY_CLIENT_SECRET"),
        private_key_pem: read_pem("RAFFLESPAY_PRIVATE_KEY"),
        gateway_public_key_pem: read_pem("RAFFLESPAY_PUBLIC_KEY"),
        callback_url: Payments.callback_url,
        transport: transport
      )
    end

    def self.fetch_env(name)
      ENV[name].presence || raise(ConfigurationError, "#{name} is not set")
    end

    # A PEM is multi-line, which env files handle badly. Prefer NAME_PATH
    # pointing at a .pem file; NAME with literal "\n" sequences also works.
    def self.read_pem(name)
      if (path = ENV["#{name}_PATH"].presence)
        File.read(path)
      elsif (value = ENV[name].presence)
        value.gsub("\\n", "\n")
      else
        raise ConfigurationError, "set #{name}_PATH (path to a .pem file) or #{name}"
      end
    end

    def initialize(base_url:, api_version:, client_id:, client_secret:, private_key_pem:, gateway_public_key_pem:,
                   callback_url:, transport: HttpTransport.new, logger: Rails.logger)
      @base_url = base_url.chomp("/")
      @api_version = api_version
      @client_id = client_id
      @client_secret = client_secret
      @private_key_pem = private_key_pem
      @gateway_public_key_pem = gateway_public_key_pem
      @callback_url = callback_url
      @transport = transport
      @logger = logger
    end

    def create_charge(transaction)
      body = {
        amount: transaction.amount_in_rupiah,
        external_id: transaction.uuid,
        callback_url: @callback_url,
        payment_method: transaction.payment_method
      }
      # Required for emoney; including it for qris is a 400.
      body[:payment_channel] = transaction.payment_channel if transaction.payment_method == "emoney"

      payload = Signer.canonical_json(body)
      status, response = @transport.call(:post, endpoint("payments"),
                                         headers: auth_headers.merge("X-Signature" => Signer.sign(payload, @private_key_pem)),
                                         body: payload)
      data = unwrap!(status, response)

      if BigDecimal(data["amount"].to_s) != body[:amount]
        raise GatewayError, "amount mismatch: sent #{body[:amount]}, gateway returned #{data['amount'].inspect}"
      end
      raise GatewayError, "external_id mismatch: #{data['external_id'].inspect}" if data["external_id"] != transaction.uuid

      checkout_url =
        if transaction.payment_method == "emoney"
          data["redirect_url"].presence || data["checkout_url"].presence
        else
          data["checkout_url"].presence || data["qris_redirect_url"].presence
        end
      raise GatewayError, "no checkout url in response" if checkout_url.blank?

      qr_content = data["qris_image_content"].presence
      if qr_content && !qr_content.start_with?(QRIS_PAYLOAD_PREFIX)
        @logger.warn("[RafflesPay] qris_image_content for #{transaction.uuid} is not a QRIS payload; ignoring it")
        qr_content = nil
      end

      Charge.new(gateway_id: data["id"], checkout_url: checkout_url, qr_content: qr_content,
                 qr_image_url: data["qris_image_url"].presence, raw: data)
    end

    def verify_webhook!(raw_body, signature)
      raise InvalidSignature, "missing X-Signature" if signature.blank?

      variant = Signer.matching_variant(raw_body, signature, @gateway_public_key_pem)
      raise InvalidSignature, "signature did not verify" unless variant

      @logger.info("[RafflesPay] callback signature matched variant=#{variant}")
      notification_from(JSON.parse(raw_body))
    end

    # GET is not signed. :id accepts our external_id. Returns nil on 404.
    def fetch_status(external_id)
      status, response = @transport.call(:get, endpoint("payments/#{ERB::Util.url_encode(external_id)}"), headers: auth_headers)
      return nil if status == 404

      # The same fields are repeated flat at the top level; read `data` only.
      notification_from(unwrap!(status, response))
    end

    private

    def endpoint(path)
      "#{@base_url}/api/#{@api_version}/#{path}"
    end

    def auth_headers
      {
        "Content-Type" => "application/json; charset=utf-8",
        "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}"
      }
    end

    def unwrap!(status, response)
      json = JSON.parse(response) rescue nil

      if (400..499).cover?(status)
        message = json&.dig("error", "message") || response.to_s.truncate(200)
        raise RequestRejected, "RafflesPay rejected the request (#{status}): #{message}"
      end
      unless status == 200 && json.is_a?(Hash) && json["success"] == true && json["data"].is_a?(Hash)
        raise GatewayError, "unexpected RafflesPay response (#{status}): #{response.to_s.truncate(200)}"
      end

      json["data"]
    end

    def notification_from(data)
      status =
        case data["status"]
        when "success" then :success
        when "failed" then :failed
        else
          # Only success/failed are documented. Anything else stays pending.
          @logger.warn("[RafflesPay] unrecognised payment status #{data['status'].inspect} for #{data['external_id']}")
          :pending
        end

      Notification.new(
        external_id: data["external_id"],
        gateway_id: data["id"],
        status: status,
        amount: data["amount"].nil? ? nil : BigDecimal(data["amount"].to_s),
        fee: data["fee"].nil? ? nil : BigDecimal(data["fee"].to_s),
        rrn: data["rrn"],
        issuer_name: data["issuer_name"],
        paid_at: parse_time(data["paid_at"]),
        raw: data
      )
    end

    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
