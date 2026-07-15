class Transaction < ApplicationRecord
  belongs_to :machine
  belongs_to :slot

  validates :status, inclusion: { in: %w[pending paid dispensed failed] }
  validates :uuid, presence: true, uniqueness: true
  
  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.status ||= 'pending'
    self.uuid ||= SecureRandom.uuid
  end
end