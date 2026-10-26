require "test_helper"

class InventoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
  end

  test "should redirect to sign in when not authenticated" do
    get inventories_url
    assert_redirected_to new_user_session_path
  end

  test "should get index when authenticated" do
    sign_in users(:one)

    get inventories_url
    assert_response :success
  end

  test "invalid product shows validation feedback and retains entered fields" do
    sign_in users(:one)
    assert_no_difference("Product.count") do
      post inventories_url, params: { product: { name: "Potato chips", price: -1 } }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='product[name]'][value='Potato chips']"
    assert_select "li", text: /Price must be greater than 0/
  end

  test "stock locations are available using an expandable control" do
    sign_in users(:one)
    get inventories_url
    assert_select "details.erp-stock-details summary", text: /machine/
    assert_select "details.erp-stock-details a[href=?]", machine_path(machines(:one))
  end

  test "inventory displays batch completion time and machine history preserves it" do
    slot = slots(:one)
    batch = StockBatch.create!(slot: slot, product: slot.product, quantity: 5, sold_quantity: 5,
      remaining_quantity: 0, stocked_at: 3.days.ago, sold_out_at: 1.day.ago + 3.hours)
    StockBatch.create!(slot: slot, product: slot.product, quantity: 4, remaining_quantity: 4, stocked_at: Time.current)
    sign_in users(:one)

    get inventories_url
    assert_response :success
    assert_select "th", text: "Batch sell-through"
    assert_select "td p", text: "Not sold out"
    assert_select "td p", text: "Last sold out: 2d 3h 0m"

    get machine_url(slot.machine)
    assert_response :success
    assert_select "section[aria-labelledby=stock-batches-title]", text: /2d 3h 0m/
    assert_equal 2.days + 3.hours, batch.sell_through_seconds
  end

  test "create attaches uploaded image to the product" do
    sign_in users(:one)

    assert_difference("Product.count") do
      post inventories_url, params: {
        product: {
          name: "Marlboro Hitam",
          price: 20_000,
          description: "Test product",
          image: fixture_file_upload("test_image.png", "image/png")
        }
      }
    end

    product = Product.order(:created_at).last
    assert product.image.attached?
    assert_redirected_to inventories_path
  end

  test "create succeeds without an image" do
    sign_in users(:one)

    assert_difference("Product.count") do
      post inventories_url, params: {
        product: { name: "No Image Product", price: 10_000 }
      }
    end

    product = Product.order(:created_at).last
    assert_not product.image.attached?
  end

  test "update replaces the attached image" do
    sign_in users(:one)
    @product.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "old.png",
      content_type: "image/png"
    )
    original_blob_id = @product.image.blob.id

    patch inventory_url(@product), params: {
      product: { image: fixture_file_upload("test_image.png", "image/png") }
    }

    @product.reload
    assert @product.image.attached?
    assert_not_equal original_blob_id, @product.image.blob.id
    assert_redirected_to inventories_path
  end

  test "index renders the attached image instead of the legacy image_url" do
    @product.update!(image_url: "https://example.com/should-not-be-used.png")
    @product.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
    sign_in users(:one)

    get inventories_url

    assert_select "img[src*=?]", "should-not-be-used.png", count: 0
  end
end
