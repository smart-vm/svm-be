require "net/http"

module Payments
  # Minimal HTTP client so the gateway can be tested with a fake transport.
  class HttpTransport
    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, IOError,
                       OpenSSL::SSL::SSLError, SystemCallError ].freeze

    def initialize(open_timeout: 5, read_timeout: 15)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Returns [status_code, body_string].
    def call(method, url, headers: {}, body: nil)
      uri = URI(url)
      request = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
      headers.each { |k, v| request[k] = v }
      request.body = body if body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: @open_timeout, read_timeout: @read_timeout, write_timeout: @read_timeout) do |http|
        http.request(request)
      end
      [ response.code.to_i, response.body.to_s ]
    rescue *NETWORK_ERRORS => e
      raise GatewayError, "network error talking to #{uri&.host}: #{e.class}: #{e.message}"
    end
  end
end
