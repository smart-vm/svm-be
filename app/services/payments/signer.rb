require "openssl"
require "base64"
require "json"

module Payments
  # SHA256withRSA over compact JSON with keys sorted recursively (RafflesPay).
  module Signer
    module_function

    def canonicalize(value)
      case value
      when Hash  then value.keys.sort_by(&:to_s).each_with_object({}) { |k, h| h[k] = canonicalize(value[k]) }
      when Array then value.map { |v| canonicalize(v) }
      else value
      end
    end

    def canonical_json(body) = JSON.generate(canonicalize(body))

    # Same, but whole-number floats written the way JavaScript does (5000.0 -> 5000).
    def canonical_json_js(body)
      js = lambda do |v|
        case v
        when Hash  then v.transform_values { |x| js.(x) }
        when Array then v.map { |x| js.(x) }
        when Float then (v % 1).zero? ? v.to_i : v
        else v
        end
      end
      JSON.generate(canonicalize(js.(body)))
    end

    def sign(str, private_pem)
      Base64.strict_encode64(OpenSSL::PKey::RSA.new(private_pem).sign(OpenSSL::Digest::SHA256.new, str))
    end

    def valid?(str, sig_b64, public_pem)
      OpenSSL::PKey::RSA.new(public_pem).verify(OpenSSL::Digest::SHA256.new, Base64.strict_decode64(sig_b64.to_s), str)
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      false
    end

    # The docs don't say how RafflesPay serialises callback floats, so try the
    # raw body first, then both canonical forms. Returns the variant that
    # matched (log it, then drop the others once you know) or nil.
    def matching_variant(raw_body, sig_b64, public_pem)
      return :raw if valid?(raw_body, sig_b64, public_pem)

      parsed = JSON.parse(raw_body)
      return :canonical if valid?(canonical_json(parsed), sig_b64, public_pem)
      return :canonical_js if valid?(canonical_json_js(parsed), sig_b64, public_pem)

      nil
    rescue JSON::ParserError
      nil
    end
  end
end
