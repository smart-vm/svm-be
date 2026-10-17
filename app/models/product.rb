class Product < ApplicationRecord
  has_many :slots
  has_many :machines, through: :slots
  has_one_attached :image
  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }
end
