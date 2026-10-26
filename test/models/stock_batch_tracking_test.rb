require "test_helper"

class StockBatchTrackingTest < ActiveSupport::TestCase
  test "a batch finishes only when all units are sold and its duration stays fixed" do
    started = 4.days.ago.change(usec: 0)
    slot = nil
    travel_to(started) { slot = create_slot(2) }
    batch = slot.stock_batches.sole

    travel_to(started + 1.day) { sell(slot) }
    assert_equal 1, batch.reload.sold_quantity
    assert_nil batch.sold_out_at
    assert_nil batch.sell_through_seconds

    travel_to(started + 2.days + 3.hours) do
      transaction = sell(slot)
      assert_not transaction.record_vend_result!("success")
    end

    assert_equal 2, batch.reload.sold_quantity
    assert_equal 0, slot.reload.current_stock
    assert_equal started + 2.days + 3.hours, batch.sold_out_at
    assert_equal 2.days + 3.hours, batch.sell_through_seconds
    assert_equal 2.days + 3.hours, batch.reload.sell_through_seconds
  end

  test "top ups form separate FIFO batches without resetting the earlier start time" do
    started = 3.days.ago.change(usec: 0)
    slot = nil
    travel_to(started) { slot = create_slot(2) }
    original = slot.stock_batches.sole
    travel_to(started + 1.hour) { sell(slot) }
    travel_to(started + 2.hours) { slot.reload.update!(current_stock: 3) }
    top_up = slot.stock_batches.order(:id).last
    assert_equal 2, top_up.quantity
    assert_equal started, original.reload.stocked_at

    travel_to(started + 1.day) { sell(slot) }
    assert original.reload.sold_out?
    assert_equal 1.day, original.sell_through_seconds
    assert_equal 0, top_up.reload.sold_quantity
    assert_equal 2, top_up.remaining_quantity
  end

  test "existing stock remains undated and is consumed before a dated top up" do
    slot = slots(:one)
    slot.update!(current_stock: 7)
    legacy, top_up = slot.stock_batches.order(:id).to_a
    assert_equal 5, legacy.quantity
    assert_nil legacy.stocked_at
    assert_equal 2, top_up.quantity
    assert_not_nil top_up.stocked_at

    5.times { sell(slot) }
    assert legacy.reload.sold_out?
    assert_nil legacy.sell_through_seconds
    assert_equal 2, top_up.reload.remaining_quantity
  end

  test "manual reductions are adjustments and cannot manufacture a sell through time" do
    slot = create_slot(3)
    batch = slot.stock_batches.sole
    slot.update!(current_stock: 1)
    assert batch.reload.adjusted?
    assert_equal 0, batch.sold_quantity
    sell(slot)

    assert_equal 1, batch.reload.sold_quantity
    assert_equal 0, batch.remaining_quantity
    assert_not batch.sold_out?
    assert_nil batch.sell_through_seconds
  end

  test "product replacements close old stock as an adjustment and start a separate batch" do
    slot = create_slot(3)
    original = slot.stock_batches.sole
    slot.update!(product: products(:two), current_stock: 2)

    assert original.reload.adjusted?
    assert_equal 0, original.remaining_quantity
    assert_equal 0, original.sold_quantity
    replacement = slot.stock_batches.order(:id).last
    assert_equal products(:two), replacement.product
    assert_equal 2, replacement.quantity
    assert_nil original.sell_through_seconds
  end

  test "failed deliveries and refunds never count as batch sales" do
    slot = create_slot(2)
    transaction = Transaction.create!(machine: slot.machine, slot: slot, amount: 15000, status: "dispensing")
    transaction.record_vend_result!("failed")
    transaction.resolve!("refunded")
    batch = slot.stock_batches.sole
    assert_equal 0, batch.sold_quantity
    assert_equal 2, batch.remaining_quantity
    assert_nil batch.sold_out_at
  end

  test "an operator-confirmed delivery consumes one unit exactly once" do
    slot = create_slot(1)
    transaction = Transaction.create!(machine: slot.machine, slot: slot, amount: 15000, status: "needs_review")
    assert transaction.resolve!("settled")
    assert_not transaction.resolve!("settled")
    assert_equal 0, slot.reload.current_stock
    assert_equal 1, slot.stock_batches.sole.sold_quantity
    assert slot.stock_batches.sole.sold_out?
  end

  test "an invalid stock edit does not create a batch or change quantities" do
    slot = create_slot(2)
    assert_no_difference("StockBatch.count") { assert_not slot.update(current_stock: -1) }
    assert_equal 2, slot.reload.current_stock
    assert_equal 2, slot.stock_batches.sole.remaining_quantity
  end

  test "confirmed delivery with no recorded stock does not invent a batch" do
    slot = create_slot(0)
    assert_no_difference("StockBatch.count") { sell(slot) }
    assert_equal 0, slot.reload.current_stock
  end

  private

  def create_slot(quantity)
    Slot.create!(machine: machines(:one), product: products(:one), slot_number: 10,
      current_stock: quantity, max_capacity: 10, status: "operational")
  end

  def sell(slot)
    transaction = Transaction.create!(machine: slot.machine, slot: slot, amount: 15000, status: "dispensing")
    transaction.record_vend_result!("success")
    transaction
  end
end
