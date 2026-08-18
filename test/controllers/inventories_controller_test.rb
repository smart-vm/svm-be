require "test_helper"

class InventoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get inventories_url
    assert_response :success
  end
end
