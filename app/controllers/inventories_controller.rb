class InventoriesController < ApplicationController
  def index
    @products = Product.includes(slots: :machine).order(created_at: :desc)
  end
end
