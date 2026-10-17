class Slot < ApplicationRecord
  belongs_to :machine
  belongs_to :product

  validates :slot_number, presence: true
end
