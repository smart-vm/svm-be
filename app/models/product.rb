class Product < ApplicationRecord
  has_many :slots
  has_many :machines, through: :slots
end
