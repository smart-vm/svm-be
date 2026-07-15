class Transaction < ApplicationRecord
  belongs_to :machine
  belongs_to :slot
end
