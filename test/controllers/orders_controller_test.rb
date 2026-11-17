require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  ITEMS = [ { slug: "belgian-chocolate-box", quantity: 2 }, { slug: "forever-yours-gift-set", quantity: 1 } ]

  # ---------- Placing an order ----------

  test "create places a pending order and returns it" do
    assert_difference -> { users(:layla).orders.count }, 1 do
      post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params
    end

    assert_response :created
    order = users(:layla).orders.order(:id).last
    data = response.parsed_body["data"]
    assert_equal order.number, data["number"]
    assert_match(/\A\d{11}\z/, data["number"])
    assert_equal [ "pending_payment", 73.0, 0.0, 73.0 ], data.values_at("status", "subtotal", "deliveryFee", "total")
    assert_equal [ "Sara Al-Sabah", "Street 3, House 18", "Block 4, Jabriya", "Hawalli" ],
                 data.values_at("recipientName", "address", "blockArea", "city")
    assert_equal [ (Date.current + 1).to_s, "15-18", "Happy birthday, Sara!\nLove, Layla", "knet" ],
                 data.values_at("deliveryDate", "deliverySlot", "giftMessage", "paymentMethod")
    assert_equal [ [ "belgian-chocolate-box", 2, 25.0 ], [ "forever-yours-gift-set", 1, 48.0 ] ],
                 data["items"].map { |item| item.values_at("productSlug", "quantity", "lineTotal") }
  end

  test "create lowers the stock" do
    post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params

    assert_equal 18, products(:chocolate_box).reload.stock
    assert_equal 5, products(:gift_set).reload.stock
  end

  test "create ignores fields the customer must not set" do
    post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params.merge(
      status: "delivered", number: "1", subtotal: 0.001, delivery_fee: 0, total: 0.001, user_id: users(:omar).id,
      items: [ { slug: "belgian-chocolate-box", quantity: 2, price: 0.001 }, { slug: "forever-yours-gift-set", quantity: 1 } ]
    )

    assert_response :created
    order = Order.find_by!(number: response.parsed_body.dig("data", "number"))
    assert_equal [ "pending_payment", BigDecimal("73"), users(:layla) ], [ order.status, order.total, order.user ]
  end

  # ---------- Cart changed ----------

  test "create refuses a cart that changed since the customer saw it" do
    products(:chocolate_box).update!(price: 13)

    assert_no_order_placed do
      post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params
    end

    assert_response :conflict
    assert_equal(
      { "error" => { "code" => "cart_changed", "message" => "Your cart has changed. Please review it before paying." } },
      response.parsed_body
    )
  end

  test "create refuses a missing or badly shaped cart" do
    [ { items: [] }, { items: "abc" }, { items: [ 1, 2 ] }, { expected_total: nil } ].each do |changes|
      assert_no_order_placed do
        post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params.merge(changes)
      end

      assert_response :conflict, "changes: #{changes.inspect}"
    end

    assert_no_order_placed do
      post orders_url, headers: bearer("layla-phone-token"), as: :json, params: {}
    end
    assert_response :conflict
  end

  # ---------- Invalid details ----------

  test "create rejects missing details with an error for each field" do
    assert_no_order_placed do
      post orders_url, headers: bearer("layla-phone-token"), as: :json, params: { items: ITEMS, expected_total: 73 }
    end

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal %w[ address blockArea city deliveryDate deliverySlot paymentMethod recipientName ],
                 response.parsed_body.dig("error", "details").keys.sort
  end

  test "create rejects a delivery date outside the next 30 days" do
    [ Date.current - 1, Date.current + 31 ].each do |date|
      post orders_url, headers: bearer("layla-phone-token"), as: :json, params: order_params(delivery_date: date)

      assert_validation_failed "deliveryDate", "must be between today and 30 days from now"
    end
  end

  test "create rejects a slot that has already started today" do
    travel_to Time.zone.local(2026, 11, 17, 13, 30) do
      token = SessionService.new.start(users(:layla))

      post orders_url, headers: bearer(token), as: :json, params: order_params(delivery_date: Date.current, delivery_slot: "12-15")

      assert_validation_failed "deliverySlot", "has already started today"
    end
  end

  test "create rejects an order over 5,000 KWD" do
    products(:gift_set).update!(price: 1100)

    post orders_url, headers: bearer("layla-phone-token"), as: :json,
         params: order_params(items: [ { slug: "forever-yours-gift-set", quantity: 5 } ], expected_total: 5500)

    assert_validation_failed "total", "must be at most 5000 KWD"
  end

  # ---------- Listing ----------

  test "index lists the user's orders newest first, without unpaid ones" do
    get orders_url, headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal [ orders(:layla_preparing).number, orders(:layla_delivered).number ], response.parsed_body["data"].pluck("number")
  end

  test "index never shows another user's orders" do
    get orders_url, headers: bearer(SessionService.new.start(users(:omar)))

    assert_equal [ orders(:omar_on_the_way).number ], response.parsed_body["data"].pluck("number")
  end

  test "index returns an empty list for a user without orders" do
    get orders_url, headers: bearer(SessionService.new.start(User.create!(mobile: "69999999")))

    assert_response :success
    assert_equal({ "data" => [] }, response.parsed_body)
  end

  test "index takes the same number of queries however many orders there are" do
    order = orders(:layla_preparing).dup.tap { |copy| copy.update!(number: "26111700001", subtotal: 9, delivery_fee: 2, total: 11) }
    order.order_items.create!(product: products(:teddy_bear), product_name_en: "Cuddly Teddy Bear Classic", unit_price: 9, quantity: 1, line_total: 9)
    token = SessionService.new.start(users(:layla))

    assert_queries_count(8) { get orders_url, headers: bearer(token) }
  end

  # ---------- Viewing one order ----------

  test "show returns the order in the API format" do
    order = orders(:layla_preparing)

    get order_url(order.number), headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal(
      {
        "number" => "26111467890",
        "status" => "preparing",
        "placedAt" => order.created_at.as_json,
        "recipientName" => "Sara Al-Sabah",
        "address" => "Street 3, House 18",
        "blockArea" => "Block 4, Jabriya",
        "city" => "Hawalli",
        "deliveryDate" => order.delivery_date.to_s,
        "deliverySlot" => "15-18",
        "giftMessage" => "Happy birthday, Sara!",
        "paymentMethod" => "mpgs",
        "subtotal" => 12.5,
        "deliveryFee" => 2.0,
        "total" => 14.5,
        "items" => [
          {
            "productSlug" => "belgian-chocolate-box",
            "nameEn" => "Belgian Chocolate Box",
            "nameAr" => nil,
            "category" => { "slug" => "cakes", "nameEn" => "Cakes", "nameAr" => nil },
            "image" => nil,
            "unitPrice" => 12.5,
            "quantity" => 1,
            "lineTotal" => 12.5
          }
        ]
      },
      response.parsed_body["data"]
    )
  end

  test "show includes an unpaid order, so payment can continue" do
    get order_url(orders(:layla_pending_payment).number), headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal "pending_payment", response.parsed_body.dig("data", "status")
  end

  test "show keeps the copied details of a deleted product" do
    get order_url(orders(:layla_delivered).number), headers: bearer("layla-phone-token")

    deleted = response.parsed_body.dig("data", "items").find { |item| item["nameEn"] == "Red Rose Grand Bouquet" }
    assert_equal [ nil, nil, nil, 18.5 ], deleted.values_at("productSlug", "category", "image", "unitPrice")
  end

  test "show of another user's or an unknown order is not found" do
    [ orders(:omar_on_the_way).number, "00000000000" ].each do |number|
      get order_url(number), headers: bearer("layla-phone-token")

      assert_response :not_found
      assert_equal({ "error" => { "code" => "not_found", "message" => "Order not found" } }, response.parsed_body)
    end
  end

  # ---------- Signing in ----------

  test "every action without a valid token is refused and places nothing" do
    requests = [
      ->(headers) { get orders_url, headers: headers },
      ->(headers) { get order_url(orders(:layla_preparing).number), headers: headers },
      ->(headers) { post orders_url, headers: headers, as: :json, params: order_params }
    ]

    requests.each do |request|
      [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
        assert_no_order_placed { request.call(headers) }

        assert_response :unauthorized
        assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
      end
    end
  end

  private
    def order_params(**changes)
      {
        items: ITEMS, expected_total: 73.0,
        recipient_name: "Sara Al-Sabah", address: "Street 3, House 18", block_area: "Block 4, Jabriya", city: "Hawalli",
        delivery_date: Date.current + 1, delivery_slot: "15-18", gift_message: "Happy birthday, Sara!\nLove, Layla",
        payment_method: "knet"
      }.merge(changes)
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_no_order_placed(&block)
      assert_no_difference [ -> { Order.count }, -> { Product.sum(:stock) } ], &block
    end

    def assert_validation_failed(key, message)
      assert_response :unprocessable_content
      assert_equal "validation_failed", response.parsed_body.dig("error", "code")
      assert_includes response.parsed_body.dig("error", "details", key), message
    end
end
