class InventoriesController < ApplicationController
  before_action :set_product, only: [ :edit, :update ]

  def index
    @products = Product.includes(slots: :machine).order(created_at: :desc)
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to inventories_path, notice: "Product successfully added to the catalog."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to inventories_path, notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    # Match the exact columns in your products table
    params.require(:product).permit(:name, :description, :price, :image)
  end
end
