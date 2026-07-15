class Machine < ApplicationRecord
  has_many :slots, dependent: :destroy
  has_many :transactions

  validates :uuid, presence: true, uniqueness: true
end