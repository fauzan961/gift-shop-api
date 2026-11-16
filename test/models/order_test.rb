require "test_helper"

class OrderTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with all the required fields" do
    assert build_order.valid?
  end

  test "fixtures are valid" do
    Order.find_each do |order|
      assert order.valid?, "#{order.number}: #{order.errors.full_messages.to_sentence}"
    end
  end

  test "requires a user" do
    assert_invalid build_order(user: nil), :user, :blank
  end

  test "belongs to its user only" do
    assert_equal [ orders(:layla_delivered), orders(:layla_preparing), orders(:layla_pending_payment) ].sort,
                 users(:layla).orders.sort
    assert_equal [ orders(:omar_on_the_way) ], users(:omar).orders.to_a
  end

  test "has its items" do
    assert_equal [ order_items(:layla_preparing_chocolate) ], orders(:layla_preparing).order_items.to_a
    assert_equal 3, orders(:layla_delivered).order_items.count
  end

  # ---------- Number ----------

  test "requires a unique number" do
    assert_invalid build_order(number: nil), :number, :blank
    assert_invalid build_order(number: orders(:layla_delivered).number), :number, :taken
  end

  # ---------- Status, slot and payment method ----------

  test "starts as pending payment" do
    assert_equal "pending_payment", Order.new.status
  end

  test "accepts every status, slot and payment method" do
    Order::STATUSES.each { |status| assert build_order(status: status).valid?, "status: #{status}" }
    Order::DELIVERY_SLOTS.each { |slot| assert build_order(delivery_slot: slot).valid?, "slot: #{slot}" }
    Order::PAYMENT_METHODS.each { |method| assert build_order(payment_method: method).valid?, "payment: #{method}" }
  end

  test "rejects an unknown status, slot or payment method" do
    [ nil, "shipped", "on-the-way" ].each { |status| assert_invalid build_order(status: status), :status, :inclusion }
    [ nil, "9-12", "09-10" ].each { |slot| assert_invalid build_order(delivery_slot: slot), :delivery_slot, :inclusion }
    [ nil, "cash", "KNET" ].each { |method| assert_invalid build_order(payment_method: method), :payment_method, :inclusion }
  end

  # ---------- Recipient and address ----------

  test "requires the recipient, address, block and area, and city" do
    %i[ recipient_name address block_area city ].each do |field|
      assert_invalid build_order(field => nil), field, :blank
      assert_invalid build_order(field => "   "), field, :blank
    end
  end

  test "limits the recipient name to 100 characters" do
    assert build_order(recipient_name: "ل" * 100).valid?
    assert_invalid build_order(recipient_name: "a" * 101), :recipient_name, :too_long
  end

  test "uses the same address lengths as saved addresses" do
    assert_invalid build_order(address: "St 1"), :address, :too_short
    assert_invalid build_order(address: "a" * 256), :address, :too_long
    %i[ block_area city ].each do |field|
      assert_invalid build_order(field => "ab"), field, :too_short
      assert_invalid build_order(field => "a" * 101), field, :too_long
    end
  end

  test "trims and collapses spaces in the recipient and address" do
    order = build_order(recipient_name: "  Layla   Al-Sabah ", address: " Street 12,\n House 4 ", block_area: " Block 5 ", city: "Kuwait   City")

    assert_equal "Layla Al-Sabah", order.recipient_name
    assert_equal "Street 12, House 4", order.address
    assert_equal "Block 5", order.block_area
    assert_equal "Kuwait City", order.city
  end

  test "requires a delivery date" do
    assert_invalid build_order(delivery_date: nil), :delivery_date, :blank
  end

  # ---------- Gift message ----------

  test "does not require a gift message" do
    assert build_order(gift_message: nil).valid?
  end

  test "keeps line breaks in the gift message but trims the ends" do
    assert_equal "Happy birthday!\nLove, Layla", build_order(gift_message: "  Happy birthday!\nLove, Layla \n").gift_message
  end

  test "stores a blank gift message as nil" do
    assert_nil build_order(gift_message: "  \n ").gift_message
  end

  test "limits the gift message to 200 characters" do
    assert build_order(gift_message: "ح" * 200).valid?
    assert_invalid build_order(gift_message: "a" * 201), :gift_message, :too_long
  end

  # ---------- Money ----------

  test "requires a subtotal above zero" do
    assert_invalid build_order(subtotal: 0, total: 2), :subtotal, :greater_than
    assert_invalid build_order(subtotal: nil), :subtotal, :not_a_number
  end

  test "allows free delivery but not a negative fee" do
    assert build_order(subtotal: 25, delivery_fee: 0, total: 25).valid?
    assert_invalid build_order(delivery_fee: -1, total: BigDecimal("11.5")), :delivery_fee, :greater_than_or_equal_to
  end

  test "requires the total to equal the subtotal plus the delivery fee" do
    assert_invalid build_order(total: 99), :total, "must equal the subtotal plus the delivery fee"
    assert_invalid build_order(total: nil), :total, :not_a_number
  end

  test "adds up fils exactly" do
    assert build_order(subtotal: BigDecimal("0.1"), delivery_fee: BigDecimal("0.2"), total: BigDecimal("0.3")).valid?
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a duplicate number" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_order(number: orders(:layla_delivered).number).save(validate: false)
    end
  end

  test "database rejects an unknown status, slot or payment method" do
    [ { status: "shipped" }, { delivery_slot: "9-12" }, { payment_method: "cash" } ].each do |attributes|
      assert_raises(ActiveRecord::CheckViolation, attributes.inspect) { build_order(**attributes).save(validate: false) }
    end
  end

  test "database rejects totals that do not add up" do
    [ { total: 99 }, { subtotal: 0, total: 2 }, { delivery_fee: -1, total: BigDecimal("11.5") } ].each do |attributes|
      assert_raises(ActiveRecord::CheckViolation, attributes.inspect) { build_order(**attributes).save(validate: false) }
    end
  end

  test "database rejects a missing required field" do
    assert_raises(ActiveRecord::NotNullViolation) { build_order(recipient_name: nil).save(validate: false) }
  end

  test "database refuses to delete a user who has orders" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      User.transaction(requires_new: true) { users(:layla).delete }
    end

    assert User.exists?(users(:layla).id)
    assert_equal 3, Order.where(user: users(:layla)).count
  end

  test "database deletes the items when the order is deleted" do
    item_ids = orders(:layla_delivered).order_items.ids

    orders(:layla_delivered).delete

    assert_empty OrderItem.where(id: item_ids)
    assert OrderItem.exists?(order_items(:omar_on_the_way_gift_set).id)
  end

  private
    def build_order(**attributes)
      Order.new({
        user: users(:omar), number: "26111699999", recipient_name: "Omar Al-Mutairi",
        address: "Street 12, House 4", block_area: "Block 5, Salmiya", city: "Kuwait City",
        delivery_date: Date.current, delivery_slot: "09-12", payment_method: "knet",
        subtotal: BigDecimal("12.5"), delivery_fee: BigDecimal("2"), total: BigDecimal("14.5")
      }.merge(attributes))
    end

    def assert_invalid(order, attribute, error_type)
      assert_not order.valid?, "expected #{attribute} #{error_type} error, but the order was valid"
      assert order.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{order.errors.details[attribute]}"
    end
end
