require "test_helper"

class MachinesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get machines_index_url
    assert_response :success
  end
end
