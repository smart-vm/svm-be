class Slot < ApplicationRecord
  belongs_to :machine
  belongs_to :product
  has_many :stock_batches, dependent: :destroy

  validates :slot_number, presence: true
  validates :current_stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_create :record_initial_batch
  after_update :record_stock_change

  # Called inside the transaction's settlement lock. The slot lock also
  # serializes sales from different transactions and back-office stock edits.
  def consume_stock_for_sale!(at:)
    with_lock do
      next if current_stock.to_i <= 0

      reconcile_tracked_stock!(current_stock.to_i, product_id)
      batch = stock_batches.where(product_id: product_id).where("remaining_quantity > 0")
        .order(Arel.sql("stocked_at ASC NULLS FIRST"), :id).first!
      sold = batch.sold_quantity + 1
      batch.update!(remaining_quantity: batch.remaining_quantity - 1, sold_quantity: sold,
        sold_out_at: sold == batch.quantity ? at : nil)
      # Bypass refill callbacks: a confirmed sale is not a manual adjustment.
      update_columns(current_stock: current_stock - 1)
    end
  end

  private

  def record_initial_batch
    add_stock_batch!(current_stock.to_i) if current_stock.to_i > 0
  end

  def record_stock_change
    return unless saved_change_to_current_stock? || saved_change_to_product_id?

    old_stock = saved_change_to_current_stock? ? current_stock_before_last_save.to_i : current_stock.to_i
    old_product = saved_change_to_product_id? ? product_id_before_last_save : product_id
    reconcile_tracked_stock!(old_stock, old_product)

    if saved_change_to_product_id?
      remove_tracked_stock!(old_stock, old_product)
      add_stock_batch!(current_stock.to_i) if current_stock.to_i > 0
    elsif current_stock.to_i > old_stock
      add_stock_batch!(current_stock.to_i - old_stock)
    elsif current_stock.to_i < old_stock
      remove_tracked_stock!(old_stock - current_stock.to_i, product_id)
    end
  end

  def add_stock_batch!(quantity, product: product_id, stocked_at: Time.current)
    stock_batches.create!(product_id: product, quantity: quantity, remaining_quantity: quantity, stocked_at: stocked_at)
  end

  def reconcile_tracked_stock!(quantity, product)
    tracked = stock_batches.where(product_id: product).sum(:remaining_quantity)
    if tracked < quantity
      # Legacy/imported stock remains eligible for FIFO consumption, but its
      # sell-through duration must stay unknown because its start date is lost.
      add_stock_batch!(quantity - tracked, product: product, stocked_at: nil)
    elsif tracked > quantity
      remove_tracked_stock!(tracked - quantity, product)
    end
  end

  def remove_tracked_stock!(quantity, product)
    return if quantity <= 0

    stock_batches.where(product_id: product).where("remaining_quantity > 0").order(id: :desc).each do |batch|
      removed = [ quantity, batch.remaining_quantity ].min
      batch.update!(remaining_quantity: batch.remaining_quantity - removed)
      quantity -= removed
      break if quantity.zero?
    end
  end
end
