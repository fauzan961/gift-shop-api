require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with all the required fields" do
    assert build_discount.valid?
  end

  test "fixtures are valid" do
    Discount.find_each do |discount|
      assert discount.valid?, "#{discount.name}: #{discount.errors.full_messages.to_sentence}"
    end
  end

  test "is active unless switched off" do
    assert Discount.new.active
    assert_invalid build_discount(active: nil), :active, :inclusion
  end

  # ---------- Name ----------

  test "requires a name of at most 100 characters" do
    assert_invalid build_discount(name: "   "), :name, :blank
    assert build_discount(name: "ع" * 100).valid?
    assert_invalid build_discount(name: "a" * 101), :name, :too_long
  end

  test "trims and collapses spaces in the name" do
    assert_equal "Eid Sale", build_discount(name: "  Eid   Sale ").name
  end

  # ---------- Type and value ----------

  test "accepts percentage and amount discounts" do
    assert build_discount(discount_type: "percentage", value: 20).valid?
    assert build_discount(discount_type: "amount", value: BigDecimal("2.5")).valid?
  end

  test "rejects any other type" do
    [ nil, "bogo", "Percentage" ].each do |type|
      assert_invalid build_discount(discount_type: type), :discount_type, :inclusion
    end
  end

  test "allows a percentage from 1 to 100" do
    [ 1, BigDecimal("12.5"), 100 ].each do |value|
      assert build_discount(discount_type: "percentage", value: value).valid?, "value: #{value}"
    end
  end

  test "rejects a percentage outside 1 to 100" do
    [ BigDecimal("0.5"), 101 ].each do |value|
      assert_invalid build_discount(discount_type: "percentage", value: value), :value, :in
    end
  end

  test "allows any amount above zero, even more than a price" do
    assert build_discount(discount_type: "amount", value: BigDecimal("0.001")).valid?
    assert build_discount(discount_type: "amount", value: 150).valid?
  end

  test "rejects an amount of zero or less" do
    [ 0, -1 ].each do |value|
      assert_invalid build_discount(discount_type: "amount", value: value), :value, :greater_than
    end
    assert_invalid build_discount(value: nil), :value, :not_a_number
  end

  # ---------- Target ----------

  test "accepts each kind of target with its own id" do
    assert build_discount(applies_to: "all").valid?
    assert build_discount(applies_to: "category", category: categories(:cakes)).valid?
    assert build_discount(applies_to: "occasion", occasion: occasions(:birthday)).valid?
    assert build_discount(applies_to: "product", product: products(:gift_set)).valid?
  end

  test "rejects an unknown kind of target" do
    assert_invalid build_discount(applies_to: "brand"), :applies_to, :inclusion
  end

  test "requires the id that matches the kind of target" do
    %w[ category occasion product ].each do |target|
      assert_invalid build_discount(applies_to: target), target.to_sym, :blank
    end
  end

  test "rejects an id that does not match the kind of target" do
    discount = build_discount(applies_to: "all", product: products(:gift_set))

    assert_includes discount.tap(&:valid?).errors.full_messages, "Product must be empty when the discount applies to all"
    assert_not build_discount(applies_to: "product", product: products(:gift_set), category: categories(:cakes)).valid?
    assert_not build_discount(applies_to: "category", category: categories(:cakes), occasion: occasions(:birthday)).valid?
  end

  # ---------- Dates ----------

  test "requires a start" do
    assert_invalid build_discount(starts_at: nil), :starts_at, :blank
  end

  test "allows no end date" do
    assert build_discount(ends_at: nil).valid?
  end

  test "requires the end to be after the start" do
    starts_at = Time.current
    assert_invalid build_discount(starts_at: starts_at, ends_at: starts_at), :ends_at, "must be after the start"
    assert_invalid build_discount(starts_at: starts_at, ends_at: 1.hour.ago), :ends_at, "must be after the start"
    assert build_discount(starts_at: starts_at, ends_at: starts_at + 1.hour).valid?
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects an unknown type or kind of target" do
    [ { discount_type: "bogo" }, { applies_to: "brand" } ].each do |attributes|
      assert_raises(ActiveRecord::CheckViolation, attributes.inspect) { build_discount(**attributes).save(validate: false) }
    end
  end

  test "database rejects a value outside the allowed range for its type" do
    [ { discount_type: "percentage", value: 101 }, { discount_type: "percentage", value: 0 }, { discount_type: "amount", value: 0 } ].each do |attributes|
      assert_raises(ActiveRecord::CheckViolation, attributes.inspect) { build_discount(**attributes).save(validate: false) }
    end
  end

  test "database rejects an end before the start" do
    assert_raises(ActiveRecord::CheckViolation) { build_discount(ends_at: 1.day.ago).save(validate: false) }
  end

  test "database accepts a target that does not match, because only the model checks it" do
    assert build_discount(applies_to: "category").save(validate: false)
  end

  test "database deletes discounts with their category, occasion or product" do
    category_discount = discounts(:cakes_week).id
    occasion_discount = discounts(:valentines).id
    product_discount = discounts(:gift_set_deal).id

    ProductCategory.where(category: categories(:cakes)).delete_all
    ProductOccasion.where(occasion: occasions(:valentines_day)).delete_all
    categories(:cakes).delete
    occasions(:valentines_day).delete
    products(:gift_set).delete

    assert_empty Discount.where(id: [ category_discount, occasion_discount, product_discount ])
    assert Discount.exists?(discounts(:eid_sale).id)
  end

  private
    def build_discount(**attributes)
      Discount.new({ name: "Eid Sale", discount_type: "percentage", value: 10, applies_to: "all", starts_at: 1.hour.ago }.merge(attributes))
    end

    def assert_invalid(discount, attribute, error_type)
      assert_not discount.valid?, "expected #{attribute} #{error_type} error, but the discount was valid"
      assert discount.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{discount.errors.details[attribute]}"
    end
end
