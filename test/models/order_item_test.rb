require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with all the required fields" do
    assert build_item.valid?
  end

  test "fixtures are valid" do
    OrderItem.find_each do |item|
      assert item.valid?, "#{item.product_name_en}: #{item.errors.full_messages.to_sentence}"
    end
  end

  test "requires an order" do
    assert_invalid build_item(order: nil), :order, :blank
  end

  test "does not require a product, so old orders survive a deleted product" do
    item = order_items(:layla_delivered_deleted_product)

    assert_nil item.product
    assert item.valid?
  end

  # ---------- Names ----------

  test "requires the English name but not the Arabic one" do
    assert_invalid build_item(product_name_en: nil), :product_name_en, :blank
    assert build_item(product_name_ar: nil).valid?
  end

  test "limits both names to 100 characters" do
    assert build_item(product_name_en: "a" * 100, product_name_ar: "ح" * 100).valid?
    assert_invalid build_item(product_name_en: "a" * 101), :product_name_en, :too_long
    assert_invalid build_item(product_name_ar: "ح" * 101), :product_name_ar, :too_long
  end

  # ---------- Price, quantity and line total ----------

  test "requires a unit price above zero" do
    assert_invalid build_item(unit_price: 0, line_total: 0), :unit_price, :greater_than
    assert_invalid build_item(unit_price: nil), :unit_price, :not_a_number
  end

  test "allows a quantity from 1 to 99" do
    assert build_item(quantity: 1, line_total: BigDecimal("12.5")).valid?
    assert build_item(quantity: 99, line_total: BigDecimal("1237.5")).valid?
  end

  test "rejects a quantity outside 1 to 99 or not a whole number" do
    assert_invalid build_item(quantity: 0, line_total: 0), :quantity, :in
    assert_invalid build_item(quantity: 100, line_total: 1250), :quantity, :in
    assert_invalid build_item(quantity: "2.5"), :quantity, :not_an_integer
    assert_invalid build_item(quantity: nil), :quantity, :not_a_number
  end

  test "requires the line total to equal the unit price times the quantity" do
    assert_invalid build_item(line_total: 30), :line_total, "must equal the unit price times the quantity"
    assert_invalid build_item(line_total: nil), :line_total, :not_a_number
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects the same product twice in one order" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_item(order: orders(:layla_preparing), product: products(:chocolate_box)).save(validate: false)
    end
  end

  test "database allows the same product in different orders" do
    assert build_item(order: orders(:omar_on_the_way), product: products(:chocolate_box)).save
  end

  test "database rejects a bad price, quantity or line total" do
    [ { unit_price: 0, line_total: 0 }, { quantity: 0, line_total: 0 }, { quantity: 100, line_total: 1250 }, { line_total: 30 } ].each do |attributes|
      assert_raises(ActiveRecord::CheckViolation, attributes.inspect) { build_item(**attributes).save(validate: false) }
    end
  end

  test "database keeps the item and its copied details when the product is deleted" do
    item = order_items(:layla_delivered_chocolate)

    products(:chocolate_box).delete
    item.reload

    assert_nil item.product_id
    assert_equal "Belgian Chocolate Box", item.product_name_en
    assert_equal BigDecimal("37.5"), item.line_total
  end

  private
    def build_item(**attributes)
      OrderItem.new({
        order: orders(:omar_on_the_way), product: products(:teddy_bear), product_name_en: "Cuddly Teddy Bear Classic",
        unit_price: BigDecimal("12.5"), original_price: BigDecimal("12.5"), quantity: 3, line_total: BigDecimal("37.5")
      }.merge(attributes))
    end

    def assert_invalid(item, attribute, error_type)
      assert_not item.valid?, "expected #{attribute} #{error_type} error, but the item was valid"
      assert item.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{item.errors.details[attribute]}"
    end
end
