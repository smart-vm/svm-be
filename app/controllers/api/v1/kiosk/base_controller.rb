# Endpoints the vending machine itself calls. Each machine authenticates with
# its own token: `Authorization: Bearer <machine.api_token>`.
class Api::V1::Kiosk::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_machine!

  attr_reader :current_machine

  private

  def authenticate_machine!
    @current_machine = authenticate_with_http_token do |token, _options|
      Machine.find_by(api_token: token) if token.present?
    end

    if @current_machine
      @current_machine.touch_heartbeat!
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
