require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "can attach an image" do
    product = products(:one)
    product.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )

    assert product.image.attached?
  end

  test "image is not required to save a product" do
    product = Product.new(name: "No Image Product", price: 10.0)

    assert product.save
    assert_not product.image.attached?
  end
end
