module ApplicationCable
  # Kiosks connect with their machine token (`Authorization: Bearer ...`).
  # Signed-in back-office users may also connect, but can't join kiosk streams.
  class Connection < ActionCable::Connection::Base
    identified_by :current_machine, :current_user

    def connect
      self.current_machine = find_machine
      self.current_user = env["warden"]&.user unless current_machine
      reject_unauthorized_connection unless current_machine || current_user
    end

    private

    def find_machine
      token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      Machine.find_by(api_token: token) if token.present?
    end
  end
end
