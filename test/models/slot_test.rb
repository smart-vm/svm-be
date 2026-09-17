require "test_helper"

class SlotTest < ActiveSupport::TestCase
  test "requires a slot_number" do
    slot = Slot.new(machine: machines(:one), product: products(:one))
    assert_not slot.valid?
    assert_includes slot.errors[:slot_number], "can't be blank"
  end

  test "requires a machine" do
    slot = Slot.new(slot_number: 1, product: products(:one))
    assert_not slot.valid?
    assert_includes slot.errors[:machine], "must exist"
  end

  test "valid with a machine, product, and slot_number" do
    slot = Slot.new(machine: machines(:one), product: products(:one), slot_number: 5)
    assert slot.valid?
  end
end
