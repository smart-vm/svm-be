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
