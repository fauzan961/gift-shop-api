require "test_helper"

class CartServiceTest < ActiveSupport::TestCase
  CHOCOLATE = "belgian-chocolate-box"
  GIFT_SET = "forever-yours-gift-set"
  TEDDY = "cuddly-teddy-bear-classic"

  setup do
    @service = CartService.new
  end

  # ---------- Lines ----------

  test "check returns each product with its quantity" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 2 }, { slug: GIFT_SET, quantity: 1 } ])

    assert_equal [ [ products(:chocolate_box), 2 ], [ products(:gift_set), 1 ] ], lines(cart)
    assert_empty cart[:unavailable]
  end

  test "check combines the same product listed twice, in any letter case" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 2 }, { slug: " Belgian-Chocolate-Box ", quantity: 1 } ])

    assert_equal [ [ products(:chocolate_box), 3 ] ], lines(cart)
  end

  test "check lowers a quantity above the stock to the stock" do
    cart = @service.check([ { slug: GIFT_SET, quantity: 50 } ])

    assert_equal [ [ products(:gift_set), 6 ] ], lines(cart)
  end

  test "check limits a quantity to 99" do
    products(:chocolate_box).update!(stock: 500)

    cart = @service.check([ { slug: CHOCOLATE, quantity: 1000 } ])

    assert_equal [ [ products(:chocolate_box), 99 ] ], lines(cart)
  end

  test "check treats a missing, zero, negative or unreadable quantity as 1" do
    [ nil, 0, -4, "abc", "2.5" ].each do |quantity|
      cart = @service.check([ { slug: CHOCOLATE, quantity: quantity } ])

      assert_equal [ [ products(:chocolate_box), 1 ] ], lines(cart), "quantity: #{quantity.inspect}"
    end
  end

  test "check accepts a quantity sent as text" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: "3" } ])

    assert_equal [ [ products(:chocolate_box), 3 ] ], lines(cart)
  end

  # ---------- Unavailable products ----------

  test "check leaves out and reports products that are out of stock, hidden or unknown" do
    cart = @service.check([
      { slug: CHOCOLATE, quantity: 1 },
      { slug: TEDDY, quantity: 1 },
      { slug: "hidden-product", quantity: 1 },
      { slug: "no-such-product", quantity: 1 }
    ])

    assert_equal [ [ products(:chocolate_box), 1 ] ], lines(cart)
    assert_equal [ TEDDY, "hidden-product", "no-such-product" ], cart[:unavailable]
  end

  test "check ignores items without a slug" do
    cart = @service.check([ { quantity: 2 }, { slug: "  ", quantity: 1 } ])

    assert_empty cart[:lines]
    assert_empty cart[:unavailable]
  end

  test "check reads only the first 50 items" do
    items = Array.new(CartService::MAX_LINES) { |n| { slug: "no-such-product-#{n}" } } + [ { slug: CHOCOLATE } ]

    cart = @service.check(items)

    assert_empty cart[:lines]
    assert_equal CartService::MAX_LINES, cart[:unavailable].size
  end

  # ---------- Totals ----------

  test "check adds up the subtotal from the saved prices" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 3 }, { slug: GIFT_SET, quantity: 2 } ])

    assert_equal BigDecimal("133.5"), cart[:subtotal]
  end

  test "check ignores any price sent with the items" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 1, price: "0.001" } ])

    assert_equal BigDecimal("12.5"), cart[:subtotal]
  end

  test "check charges delivery below 25 KWD" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 1 } ])

    assert_equal BigDecimal("12.5"), cart[:subtotal]
    assert_equal BigDecimal("2"), cart[:delivery_fee]
    assert_equal BigDecimal("14.5"), cart[:total]
  end

  test "check makes delivery free from exactly 25 KWD" do
    cart = @service.check([ { slug: CHOCOLATE, quantity: 2 } ])

    assert_equal BigDecimal("25"), cart[:subtotal]
    assert_equal BigDecimal("0"), cart[:delivery_fee]
    assert_equal BigDecimal("25"), cart[:total]
  end

  test "check keeps fils exact without rounding errors" do
    products(:chocolate_box).update!(price: BigDecimal("0.1"))
    products(:gift_set).update!(price: BigDecimal("0.2"))

    cart = @service.check([ { slug: CHOCOLATE, quantity: 1 }, { slug: GIFT_SET, quantity: 1 } ])

    assert_equal BigDecimal("0.3"), cart[:subtotal]
  end

  test "check returns zero totals and no delivery for an empty cart" do
    [ [], nil, [ { slug: TEDDY } ] ].each do |items|
      cart = @service.check(items)

      assert_empty cart[:lines], "items: #{items.inspect}"
      assert_equal 0, cart[:subtotal]
      assert_equal 0, cart[:delivery_fee]
      assert_equal 0, cart[:total]
    end
  end

  # ---------- Queries ----------

  test "check loads every product in a fixed number of queries" do
    items = [ { slug: CHOCOLATE }, { slug: GIFT_SET }, { slug: TEDDY }, { slug: "no-such-product" } ]

    assert_queries_count(4) { @service.check(items) }
  end

  private
    def lines(cart)
      cart[:lines].map { |line| [ line[:product], line[:quantity] ] }
    end
end
