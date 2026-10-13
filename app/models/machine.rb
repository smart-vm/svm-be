class Machine < ApplicationRecord
  has_many :slots, dependent: :destroy
  has_many :transactions
  has_many :advertisement_machines, dependent: :destroy

  has_secure_token :api_token, length: 32

  validates :uuid, presence: true, uniqueness: true

  before_validation :set_uuid, on: :create

  # ActionCable stream the kiosk listens on for its own transactions.
  def transaction_stream
    "machine_transaction_channel_#{uuid}"
  end

  def broadcast_to_kiosk(payload)
    ActionCable.server.broadcast(transaction_stream, payload)
  end

  def touch_heartbeat!
    return if last_heartbeat_at && last_heartbeat_at > 30.seconds.ago

    update_column(:last_heartbeat_at, Time.current)
  end

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
