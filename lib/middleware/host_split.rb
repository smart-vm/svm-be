# Serves the one Rails app under two hostnames so the public API and the back
# office are separate sites:
#
#   API_HOST        (api.vendoravm.com)        kiosk API, payment webhook, cable, images
#   CMS_HOST        (cms.vendoravm.com)        the back office (CMS); never the API
#
# Hosts that match neither (localhost in development, the bare server IP during
# the migration) keep serving everything.
module Middleware
  class HostSplit
    API_PATHS = %r{\A/(?:api/|cable\z|cable/|up\z|rails/active_storage/)}
    NOT_FOUND = [ 404, { "content-type" => "application/json" }, [ %({"error":"not found"}) ] ].freeze

    def initialize(app, api_host: -> { Rails.configuration.x.api_host }, cms_host: -> { Rails.configuration.x.cms_host })
      @app = app
      @api_host = api_host
      @cms_host = cms_host
    end

    def call(env)
      host = env["HTTP_HOST"].to_s.split(":").first.to_s.downcase
      path = env["PATH_INFO"].to_s

      if host.present? && host == @api_host.call && !API_PATHS.match?(path)
        return not_found
      end
      if host.present? && host == @cms_host.call && path.start_with?("/api/")
        return not_found
      end

      @app.call(env)
    end

    private

    def not_found
      status, headers, body = NOT_FOUND
      [ status, headers.dup, body ]
    end
  end
end
