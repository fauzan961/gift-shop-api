require "test_helper"

class OrderServiceTest < ActiveSupport::TestCase
  CHOCOLATE = "belgian-chocolate-box"
  GIFT_SET = "forever-yours-gift-set"
  ITEMS = [ { slug: CHOCOLATE, quantity: 2 }, { slug: GIFT_SET, quantity: 1 } ]

  setup do
    @service = OrderService.new
  end

  # ---------- Placing an order ----------

  test "place saves a pending order with the details and the cart totals" do
    order = place

    assert order.persisted?
    assert_equal users(:omar), order.user
    assert_equal "pending_payment", order.status
    assert_equal [ "Sara Al-Sabah", "Street 3, House 18", "Block 4, Jabriya", "Hawalli" ],
                 [ order.recipient_name, order.address, order.block_area, order.city ]
    assert_equal [ Date.current + 1, "15-18", "knet" ], [ order.delivery_date, order.delivery_slot, order.payment_method ]
    assert_equal [ BigDecimal("73"), BigDecimal("0"), BigDecimal("73") ], [ order.subtotal, order.delivery_fee, order.total ]
  end

  test "place copies each product's names and price onto the items" do
    order = place

    assert_equal(
      [
        [ products(:chocolate_box), "Belgian Chocolate Box", nil, BigDecimal("12.5"), 2, BigDecimal("25") ],
        [ products(:gift_set), "Forever Yours Gift Set", "طقم هدايا للأبد لك", BigDecimal("48"), 1, BigDecimal("48") ]
      ],
      order.order_items.order(:id).map { |item| [ item.product, item.product_name_en, item.product_name_ar, item.unit_price, item.quantity, item.line_total ] }
    )
  end

  test "place lowers the stock of each product" do
    place

    assert_equal 18, products(:chocolate_box).reload.stock
    assert_equal 5, products(:gift_set).reload.stock
  end

  test "place charges and records the sale price of a discounted product" do
    DiscountService.new.refresh

    order = place(items: [ { slug: CHOCOLATE, quantity: 2 } ], expected_total: "22")

    item = order.order_items.sole
    assert_equal [ BigDecimal("10"), BigDecimal("20") ], [ item.unit_price, item.line_total ]
    assert_equal [ BigDecimal("20"), BigDecimal("2"), BigDecimal("22") ], [ order.subtotal, order.delivery_fee, order.total ]
  end

  test "place charges delivery below 25 KWD" do
    order = place(items: [ { slug: CHOCOLATE, quantity: 1 } ], expected_total: "14.5")

    assert_equal [ BigDecimal("12.5"), BigDecimal("2"), BigDecimal("14.5") ], [ order.subtotal, order.delivery_fee, order.total ]
  end

  test "place keeps line breaks in the gift message" do
    assert_equal "Happy birthday!\nLove, Omar", place(details: { gift_message: "Happy birthday!\nLove, Omar" }).gift_message
  end

  # ---------- Order number ----------

  test "place numbers the order with today's date in Kuwait and five random digits" do
    # 22:00 UTC on 16 November is already 01:00 on 17 November in Kuwait.
    travel_to Time.utc(2026, 11, 16, 22, 0) do
      with_random_numbers(48213) do
        assert_equal "26111748213", place.number
      end
    end
  end

  test "place pads the random digits with zeros" do
    travel_to Time.zone.local(2026, 11, 17, 10, 0) do
      with_random_numbers(7) do
        assert_equal "26111700007", place.number
      end
    end
  end

  test "place picks another number when the first one is taken" do
    travel_to Time.zone.local(2026, 11, 16, 10, 0) do
      assert_equal "26111600001", orders(:layla_pending_payment).number

      with_random_numbers(1, 2) do
        assert_equal "26111600002", place.number
      end
    end
  end

  # ---------- Cart changed ----------

  test "place refuses a cart whose total differs from what the customer saw" do
    [ "70", "73.001", "", nil, "abc" ].each do |expected_total|
      assert_cart_changed { place(expected_total: expected_total) }
    end
  end

  test "place accepts the expected total in any number format" do
    [ 73, 73.0, "73", "73.000" ].each do |expected_total|
      assert place(expected_total: expected_total).persisted?, "expected_total: #{expected_total.inspect}"
    end
  end

  test "place refuses a cart when a price changed after the customer saw it" do
    products(:chocolate_box).update!(price: 13)

    assert_cart_changed { place }
  end

  test "place refuses a cart with an unavailable product" do
    [ "cuddly-teddy-bear-classic", "hidden-product", "no-such-product" ].each do |slug|
      assert_cart_changed { place(items: ITEMS + [ { slug: slug, quantity: 1 } ]) }
    end
  end

  test "place refuses an empty cart" do
    [ [], nil ].each do |items|
      assert_cart_changed { place(items: items, expected_total: "0") }
    end
  end

  test "place refuses a quantity that was lowered to the stock" do
    assert_cart_changed { place(items: [ { slug: GIFT_SET, quantity: 10 } ], expected_total: "480") }
  end

  # ---------- Delivery date and slot ----------

  test "place allows delivery from today up to 30 days ahead" do
    travel_to Time.zone.local(2026, 11, 17, 8, 0) do
      assert place(details: { delivery_date: Date.current, delivery_slot: "09-12" }).persisted?
      assert place(details: { delivery_date: Date.current + 30 }).persisted?
    end
  end

  test "place refuses delivery in the past or more than 30 days ahead" do
    [ Date.current - 1, Date.current + 31 ].each do |date|
      assert_invalid_order(:delivery_date, "must be between today and 30 days from now") { place(details: { delivery_date: date }) }
    end
  end

  test "place refuses a slot that has already started today" do
    travel_to Time.zone.local(2026, 11, 17, 13, 30) do
      [ "09-12", "12-15" ].each do |slot|
        assert_invalid_order(:delivery_slot, "has already started today") do
          place(details: { delivery_date: Date.current, delivery_slot: slot })
        end
      end

      assert place(details: { delivery_date: Date.current, delivery_slot: "15-18" }).persisted?
    end
  end

  test "place allows any slot on a later day" do
    travel_to Time.zone.local(2026, 11, 17, 20, 0) do
      assert place(details: { delivery_date: Date.current + 1, delivery_slot: "09-12" }).persisted?
    end
  end

  # ---------- Other problems ----------

  test "place reports every problem with the details together" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      place(details: { recipient_name: "", delivery_slot: "9-12", payment_method: "cash", delivery_date: Date.current - 1 })
    end

    assert_equal %i[ recipient_name delivery_slot payment_method delivery_date ].sort, error.record.errors.attribute_names.sort
  end

  test "place refuses an order over 5,000 KWD" do
    products(:gift_set).update!(price: 1100)

    assert_invalid_order(:total, "must be at most 5000 KWD") do
      place(items: [ { slug: GIFT_SET, quantity: 5 } ], expected_total: "5500")
    end
  end

  test "place allows an order of exactly 5,000 KWD" do
    products(:gift_set).update!(price: 1000)

    assert place(items: [ { slug: GIFT_SET, quantity: 5 } ], expected_total: "5000").persisted?
  end

  # ---------- Stock running out while placing ----------

  test "place undoes all stock changes when a product sells out after the cart check" do
    # Stock is lowered in id order, so sell out the later product to make sure an earlier one is put back.
    first, last = [ products(:chocolate_box), products(:gift_set) ].sort_by(&:id)
    first_stock = first.stock

    with_sold_out_after_cart_check(last.slug) do
      assert_no_difference -> { Order.count } do
        assert_raises(OrderService::CartChanged) { place }
      end
    end

    assert_equal first_stock, first.reload.stock
  end

  test "place undoes its stock changes even when called inside another transaction" do
    first, last = [ products(:chocolate_box), products(:gift_set) ].sort_by(&:id)
    first_stock = first.stock

    with_sold_out_after_cart_check(last.slug) do
      ActiveRecord::Base.transaction do
        assert_raises(OrderService::CartChanged) { place }
      end
    end

    assert_equal first_stock, first.reload.stock
  end

  # ---------- Expiring unpaid orders ----------

  test "expire_unpaid expires orders unpaid for over 30 minutes and returns their stock" do
    @service.expire_unpaid

    assert_equal "expired", orders(:layla_pending_payment).reload.status
    assert_equal 1, products(:teddy_bear).reload.stock
  end

  test "expire_unpaid leaves an order alone for its first 30 minutes" do
    order = place

    travel 29.minutes do
      @service.expire_unpaid
      assert_equal "pending_payment", order.reload.status
      assert_equal 18, products(:chocolate_box).reload.stock
    end

    travel 31.minutes do
      @service.expire_unpaid
      assert_equal "expired", order.reload.status
      assert_equal 20, products(:chocolate_box).reload.stock
      assert_equal 6, products(:gift_set).reload.stock
    end
  end

  test "expire_unpaid never touches paid or already finished orders" do
    paid = %i[ layla_delivered layla_preparing omar_on_the_way ].map { |name| orders(name) }
    paid.first.update!(status: "cancelled")

    assert_no_difference -> { Product.where.not(slug: "cuddly-teddy-bear-classic").sum(:stock) } do
      @service.expire_unpaid
    end

    assert_equal %w[ cancelled preparing on_the_way ], paid.map { |order| order.reload.status }
  end

  test "expire_unpaid returns stock only once when run again" do
    2.times { @service.expire_unpaid }

    assert_equal 1, products(:teddy_bear).reload.stock
  end

  test "expire_unpaid skips an order that was paid just before it could be locked" do
    with_paid_before_lock(orders(:layla_pending_payment)) do
      @service.expire_unpaid
    end

    assert_equal "preparing", orders(:layla_pending_payment).reload.status
    assert_equal 0, products(:teddy_bear).reload.stock
  end

  test "expire_unpaid still expires an order whose product was deleted" do
    products(:teddy_bear).delete

    @service.expire_unpaid

    assert_equal "expired", orders(:layla_pending_payment).reload.status
    assert_nil order_items(:layla_pending_payment_teddy_bear).reload.product_id
  end

  private
    def place(items: ITEMS, expected_total: "73", details: {})
      @service.place(users(:omar), items: items, expected_total: expected_total, details: {
        recipient_name: "Sara Al-Sabah", address: "Street 3, House 18", block_area: "Block 4, Jabriya", city: "Hawalli",
        delivery_date: Date.current + 1, delivery_slot: "15-18", payment_method: "knet"
      }.merge(details))
    end

    def assert_cart_changed(&block)
      assert_no_difference [ -> { Order.count }, -> { OrderItem.count }, -> { Product.sum(:stock) } ] do
        error = assert_raises(OrderService::CartChanged, &block)
        assert_equal "Your cart has changed. Please review it before paying.", error.message
      end
    end

    def assert_invalid_order(attribute, message, &block)
      assert_no_difference [ -> { Order.count }, -> { Product.sum(:stock) } ] do
        error = assert_raises(ActiveRecord::RecordInvalid, &block)
        assert_includes error.record.errors[attribute], message
      end
    end

    def with_random_numbers(*values)
      SecureRandom.define_singleton_method(:random_number) { |*| values.length > 1 ? values.shift : values.first }
      yield
    ensure
      SecureRandom.singleton_class.remove_method(:random_number)
    end

    # Marks the order paid after the expiry query has picked it up, as a payment confirmation arriving at that moment would.
    def with_paid_before_lock(order)
      original = Order.instance_method(:with_lock)
      Order.define_method(:with_lock) do |*args, &block|
        Order.where(id: order.id).update_all(status: "preparing")
        original.bind_call(self, *args, &block)
      end
      yield
    ensure
      Order.define_method(:with_lock, original)
    end

    def with_sold_out_after_cart_check(slug)
      original = CartService.instance_method(:check)
      CartService.define_method(:check) do |items|
        original.bind_call(self, items).tap { Product.where(slug: slug).update_all(stock: 0) }
      end
      yield
    ensure
      CartService.define_method(:check, original)
    end
end
