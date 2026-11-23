require "test_helper"

class DiscountServiceTest < ActiveSupport::TestCase
  # Running in the fixtures: Eid Sale (10% off everything) and Cakes Week (2.500 KWD off Cakes).
  # Not running: Valentine's (starts in 30 days), Gift Set Deal (ended) and Flash Sale (switched off).

  setup do
    @service = DiscountService.new
  end

  # ---------- Which discounts count ----------

  test "refresh applies the running discounts, keeping the lowest price for each product" do
    @service.refresh

    assert_sale products(:chocolate_box), "10.0", 20    # Cakes Week 10.000 beats Eid 11.250
    assert_sale products(:teddy_bear), "6.5", 28        # Cakes Week 6.500 beats Eid 8.100
    assert_sale products(:gift_set), "43.2", 10         # Eid 43.200 beats Cakes Week 45.500
    assert_sale products(:hidden_product), "4.5", 10    # Eid only
  end

  test "refresh ignores discounts that are switched off, not started or already over" do
    discounts(:eid_sale).update!(active: false)
    discounts(:cakes_week).update!(active: false)

    @service.refresh

    Product.find_each { |product| assert_sale product, product.price.to_s, 0 }
  end

  test "refresh starts a discount when its start time arrives" do
    travel_to discounts(:valentines).starts_at + 1.minute do
      discounts(:cakes_week).update!(active: false)

      @service.refresh

      assert_sale products(:gift_set), "40.8", 15       # Valentine's, now running; Eid has ended
      assert_sale products(:chocolate_box), "12.5", 0   # not linked to Valentine's Day
    end
  end

  test "refresh puts prices back when a discount ends" do
    @service.refresh
    discounts(:cakes_week).update!(active: false)

    travel_to discounts(:eid_sale).ends_at + 1.minute do
      @service.refresh
    end

    Product.find_each { |product| assert_sale product, product.price.to_s, 0 }
  end

  # ---------- Targets ----------

  test "refresh applies a category discount through any of the product's categories" do
    discounts(:eid_sale).update!(active: false)

    @service.refresh

    assert_sale products(:gift_set), "45.5", 5          # Cakes is the gift set's second category
    assert_sale products(:hidden_product), "5.0", 0     # Flowers only
  end

  test "refresh applies an occasion discount to the products linked to it" do
    discounts(:valentines).update!(starts_at: 1.hour.ago, ends_at: 1.day.from_now)
    disable_fixture_discounts

    @service.refresh

    assert_sale products(:gift_set), "40.8", 15
    assert_sale products(:teddy_bear), "9.0", 0
  end

  test "refresh applies a product discount to that product only" do
    disable_fixture_discounts
    Discount.create!(name: "Deal", discount_type: "percentage", value: 30, applies_to: "product", product: products(:gift_set), starts_at: 1.hour.ago)

    @service.refresh

    assert_sale products(:gift_set), "33.6", 30
    assert_sale products(:chocolate_box), "12.5", 0
  end

  # ---------- Prices ----------

  test "refresh rounds a percentage discount to the nearest fils" do
    disable_fixture_discounts
    products(:chocolate_box).update!(price: BigDecimal("12.347"))
    running_discount(discount_type: "percentage", value: 15)

    @service.refresh

    assert_sale products(:chocolate_box), "10.495", 15  # 12.347 × 0.85 = 10.49495, rounded up
  end

  test "refresh skips a discount that would make a price zero or less" do
    disable_fixture_discounts
    running_discount(discount_type: "amount", value: 9)
    running_discount(discount_type: "percentage", value: 100)

    @service.refresh

    assert_sale products(:teddy_bear), "9.0", 0         # 9 KWD off a 9 KWD product
    assert_sale products(:chocolate_box), "3.5", 72     # 9 KWD off 12.500 still applies
  end

  test "refresh never raises a price above the normal price" do
    disable_fixture_discounts

    @service.refresh

    Product.find_each { |product| assert_operator product.sale_price, :<=, product.price }
  end

  # ---------- Writing ----------

  test "refresh writes nothing when no price has changed" do
    @service.refresh

    assert_queries_match(/UPDATE "products"/, count: 0) { @service.refresh }
  end

  private
    def assert_sale(product, sale_price, discount_percent)
      product.reload
      assert_equal [ BigDecimal(sale_price), discount_percent ], [ product.sale_price, product.discount_percent ], product.slug
    end

    def disable_fixture_discounts
      Discount.where(id: [ discounts(:eid_sale).id, discounts(:cakes_week).id ]).update_all(active: false)
    end

    def running_discount(**attributes)
      Discount.create!({ name: "Test", applies_to: "all", starts_at: 1.hour.ago }.merge(attributes))
    end
end
