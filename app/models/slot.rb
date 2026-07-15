class Slot < ApplicationRecord
  belongs_to :machine
  belongs_to :product, optional: true

  validates :slot_number, presence: true
end