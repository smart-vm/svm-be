class StockBatch < ApplicationRecord
  belongs_to :slot
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :remaining_quantity, :sold_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.latest_for_slots(slot_ids, completed_only: false)
    batches = joins(:slot).where(slot_id: slot_ids).where("stock_batches.product_id = slots.product_id")
    batches = batches.where.not(sold_out_at: nil).where("stock_batches.sold_quantity = stock_batches.quantity") if completed_only
    batches.select("DISTINCT ON (stock_batches.slot_id) stock_batches.*").order(:slot_id, id: :desc).index_by(&:slot_id)
  end

  def adjusted?
    remaining_quantity + sold_quantity < quantity
  end

  def sold_out?
    sold_quantity == quantity && sold_out_at.present?
  end

  def sell_through_seconds
    return unless stocked_at && sold_out?

    [ (sold_out_at - stocked_at).to_i, 0 ].max
  end
end
