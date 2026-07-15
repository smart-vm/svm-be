class Machine < ApplicationRecord
  has_many :slots, dependent: :destroy
  has_many :transactions

  validates :uuid, presence: true, uniqueness: true

  before_validation :set_uuid, on: :create

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end