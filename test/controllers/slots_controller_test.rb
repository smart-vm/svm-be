require "test_helper"

class SlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @machine = machines(:one)
    @slot = slots(:one)
  end

  test "should redirect to sign in when not authenticated" do
    get new_slot_url(machine_id: @machine.id)
    assert_redirected_to new_user_session_path
  end

  test "should get new" do
    sign_in users(:one)

    get new_slot_url(machine_id: @machine.id)
    assert_response :success
  end

  test "create with valid params adds a slot to the machine" do
    sign_in users(:one)

    assert_difference("@machine.slots.count") do
      post slots_url, params: {
        slot: {
          machine_id: @machine.id,
          product_id: products(:one).id,
          slot_number: 9,
          current_stock: 5,
          max_capacity: 10,
          status: "operational"
        }
      }
    end

    assert_redirected_to machine_path(@machine)
  end

  test "create without a slot_number fails validation" do
    sign_in users(:one)

    assert_no_difference("Slot.count") do
      post slots_url, params: {
        slot: { machine_id: @machine.id, product_id: products(:one).id }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    sign_in users(:one)

    get edit_slot_url(@slot)
    assert_response :success
  end

  test "update with valid params updates the slot" do
    sign_in users(:one)

    patch slot_url(@slot), params: { slot: { current_stock: 3 } }

    assert_redirected_to machine_path(@slot.machine)
    assert_equal 3, @slot.reload.current_stock
  end
end
