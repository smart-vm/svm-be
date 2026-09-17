require "test_helper"

class MachinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @machine = machines(:one)
  end

  test "should redirect to sign in when not authenticated" do
    get machines_url
    assert_redirected_to new_user_session_path
  end

  test "should get index when authenticated" do
    sign_in users(:one)

    get machines_url
    assert_response :success
  end

  test "should get new" do
    sign_in users(:one)

    get new_machine_url
    assert_response :success
  end

  test "create with valid params deploys a new machine" do
    sign_in users(:one)

    assert_difference("Machine.count") do
      post machines_url, params: { machine: { location_name: "Jakarta Mall Unit 02", status: "active" } }
    end

    assert_redirected_to machines_path
  end

  test "should get edit" do
    sign_in users(:one)

    get edit_machine_url(@machine)
    assert_response :success
  end

  test "update with valid params updates the machine" do
    sign_in users(:one)

    patch machine_url(@machine), params: { machine: { location_name: "Relocated Unit" } }

    assert_redirected_to machines_path
    assert_equal "Relocated Unit", @machine.reload.location_name
  end

  test "should get show" do
    sign_in users(:one)

    get machine_url(@machine)
    assert_response :success
  end
end
