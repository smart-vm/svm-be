class Api::V1::Kiosk::CatalogsController < Api::V1::Kiosk::BaseController
  def show
    slots = current_machine.slots.includes(product: { image_attachment: :blob }).order(:slot_number)

    render json: {
      machine: { uuid: current_machine.uuid, location_name: current_machine.location_name, status: current_machine.status },
      items: slots.select(&:product).map { |slot| item_json(slot) }
    }
  end

  private

  def item_json(slot)
    product = slot.product
    {
      slot_id: slot.id,
      slot_number: slot.slot_number,
      product_id: product.id,
      name: product.name,
      description: product.description,
      price: product.price.to_i,
      stock: slot.current_stock.to_i,
      image_url: product.image.attached? ? rails_blob_url(product.image) : product.image_url.presence
    }
  end
end
