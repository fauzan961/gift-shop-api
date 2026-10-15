require "test_helper"

class ProductImageTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a product and an image" do
    assert build_image.valid?
  end

  test "fixtures are valid" do
    ProductImage.find_each do |image|
      assert image.valid?, "#{image.image}: #{image.errors.full_messages.to_sentence}"
    end
  end

  # ---------- Product ----------

  test "requires a product" do
    assert_invalid build_image(product: nil), :product, :blank
  end

  # ---------- Image path ----------

  test "requires an image path" do
    assert_invalid build_image(image: nil), :image, :blank
    assert_invalid build_image(image: "   "), :image, :blank
  end

  test "strips spaces from the image path" do
    assert_equal "/assets/images/cake.jpg", build_image(image: "  /assets/images/cake.jpg  ").image
  end

  # ---------- Position ----------

  test "defaults position to 0" do
    assert_equal 0, ProductImage.new.position
  end

  test "requires position to be a whole number of 0 or more" do
    assert_invalid build_image(position: nil), :position, :not_a_number
    assert_invalid build_image(position: -1), :position, :greater_than_or_equal_to
    assert_invalid build_image(position: 1.5), :position, :not_an_integer
  end

  test "allows two images of a product to share a position" do
    taken = product_images(:gift_set_pendant_image).position

    assert build_image(product: products(:gift_set), position: taken).save
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a missing image path" do
    assert_raises(ActiveRecord::NotNullViolation) { build_image(image: nil).save(validate: false) }
  end

  test "database rejects an empty position" do
    assert_raises(ActiveRecord::NotNullViolation) { build_image(position: nil).save(validate: false) }
  end

  test "database rejects an image for a product that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_image(product: nil, product_id: 0).save(validate: false)
    end
  end

  private
    def build_image(**attributes)
      ProductImage.new({ product: products(:chocolate_box), image: "/assets/images/chocolates.jpg" }.merge(attributes))
    end

    def assert_invalid(image, attribute, error_type)
      assert_not image.valid?, "expected #{attribute} #{error_type} error, but the image was valid"
      assert image.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{image.errors.details[attribute]}"
    end
end
