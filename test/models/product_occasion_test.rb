require "test_helper"

class ProductOccasionTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a product and an occasion" do
    assert build_link.valid?
  end

  test "fixtures are valid" do
    ProductOccasion.find_each do |link|
      assert link.valid?, "#{link.product.slug} / #{link.occasion.slug}: #{link.errors.full_messages.to_sentence}"
    end
  end

  # ---------- Required links ----------

  test "requires a product" do
    assert_invalid build_link(product: nil), :product, :blank
  end

  test "requires an occasion" do
    assert_invalid build_link(occasion: nil), :occasion, :blank
  end

  # ---------- Uniqueness ----------

  test "rejects linking the same occasion to a product twice" do
    assert_invalid build_link(product: products(:gift_set), occasion: occasions(:birthday)), :occasion_id, :taken
  end

  test "allows the same occasion on different products" do
    assert build_link(product: products(:chocolate_box), occasion: occasions(:birthday)).valid?
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects linking the same occasion to a product twice" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_link(product: products(:gift_set), occasion: occasions(:birthday)).save(validate: false)
    end
  end

  test "database rejects a link to a product that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_link(product: nil, product_id: 0).save(validate: false)
    end
  end

  test "database rejects a link to an occasion that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_link(occasion: nil, occasion_id: 0).save(validate: false)
    end
  end

  private
    # The chocolate box has no occasions, so any occasion is free to link.
    def build_link(**attributes)
      ProductOccasion.new({ product: products(:chocolate_box), occasion: occasions(:valentines_day) }.merge(attributes))
    end

    def assert_invalid(link, attribute, error_type)
      assert_not link.valid?, "expected #{attribute} #{error_type} error, but the link was valid"
      assert link.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{link.errors.details[attribute]}"
    end
end
