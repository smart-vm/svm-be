require "test_helper"

class MachineTest < ActiveSupport::TestCase
  test "auto-generates a uuid on create when none is given" do
    machine = Machine.create!(location_name: "Test Site", status: "active")
    assert machine.uuid.present?
  end

  test "does not overwrite an explicitly assigned uuid" do
    fixed_uuid = "11111111-1111-1111-1111-111111111111"
    machine = Machine.new(location_name: "Test Site", status: "active", uuid: fixed_uuid)
    machine.save!
    assert_equal fixed_uuid, machine.uuid
  end

  test "uuid must be unique" do
    duplicate = Machine.new(location_name: "Another Site", status: "active", uuid: machines(:one).uuid)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uuid], "has already been taken"
  end

  test "destroying a machine destroys its slots" do
    machine = Machine.create!(location_name: "Isolated Site", status: "active")
    machine.slots.create!(product: products(:one), slot_number: 1)
    machine.slots.create!(product: products(:two), slot_number: 2)

    assert_difference("Slot.count", -2) do
      machine.destroy
    end
  end
end
