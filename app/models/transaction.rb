class Transaction < ApplicationRecord
  belongs_to :machine
  belongs_to :slot

  validates :status, inclusion: { in: %w[pending paid dispensed failed] }
  
  before_validation :set_default_status, on: :create

  private

  def set_default_status
    self.status ||= 'pending'
  end
end