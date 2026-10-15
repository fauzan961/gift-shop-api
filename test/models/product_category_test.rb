require "test_helper"

class ProductCategoryTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a product and a category" do
    assert build_link.valid?
  end

  test "fixtures are valid" do
    ProductCategory.find_each do |link|
      assert link.valid?, "#{link.product.slug} / #{link.category.slug}: #{link.errors.full_messages.to_sentence}"
    end
  end

  # ---------- Required links ----------

  test "requires a product" do
    assert_invalid build_link(product: nil), :product, :blank
  end

  test "requires a category" do
    assert_invalid build_link(category: nil), :category, :blank
  end

  # ---------- Uniqueness ----------

  test "rejects linking the same category to a product twice" do
    assert_invalid build_link(product: products(:gift_set), category: categories(:flowers)), :category_id, :taken
  end

  test "allows the same category on different products" do
    assert build_link(product: products(:teddy_bear), category: categories(:flowers)).valid?
  end

  # ---------- Main category flag ----------

  test "defaults the main category flag to false" do
    assert_not ProductCategory.new.primary_category
  end

  test "allows the main category flag to be true or false but not empty" do
    assert build_link(primary_category: true).valid?
    assert_invalid build_link(primary_category: nil), :primary_category, :inclusion
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects linking the same category to a product twice" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_link(product: products(:gift_set), category: categories(:flowers)).save(validate: false)
    end
  end

  test "database rejects a second main category for a product" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_link(product: products(:gift_set), category: categories(:hidden), primary_category: true).save(validate: false)
    end
  end

  test "database rejects a link to a product that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_link(product: nil, product_id: 0).save(validate: false)
    end
  end

  test "database rejects a link to a category that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_link(category: nil, category_id: 0).save(validate: false)
    end
  end

  test "database rejects an empty main category flag" do
    assert_raises(ActiveRecord::NotNullViolation) do
      build_link(primary_category: nil).save(validate: false)
    end
  end

  private
    # The chocolate box is only linked to cakes, so flowers is free to link.
    def build_link(**attributes)
      ProductCategory.new({ product: products(:chocolate_box), category: categories(:flowers) }.merge(attributes))
    end

    def assert_invalid(link, attribute, error_type)
      assert_not link.valid?, "expected #{attribute} #{error_type} error, but the link was valid"
      assert link.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{link.errors.details[attribute]}"
    end
end
