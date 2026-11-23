require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  CHOCOLATE = "belgian-chocolate-box"
  GIFT_SET = "forever-yours-gift-set"

  # ---------- Checking a cart ----------

  test "check returns the items with saved prices and the totals" do
    post cart_check_url, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 2 }, { slug: GIFT_SET, quantity: 1 } ] }

    assert_response :success
    assert_equal(
      {
        "data" => {
          "items" => [
            { "product" => product_json(:chocolate_box), "quantity" => 2, "lineTotal" => 25.0 },
            { "product" => product_json(:gift_set), "quantity" => 1, "lineTotal" => 48.0 }
          ],
          "unavailable" => [],
          "subtotal" => 73.0,
          "deliveryFee" => 0.0,
          "total" => 73.0
        }
      },
      response.parsed_body
    )
  end

  test "check charges the sale price of a discounted product" do
    DiscountService.new.refresh

    post cart_check_url, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 2 } ] }

    data = response.parsed_body["data"]
    assert_equal [ 12.5, 10.0, 20.0 ], [ data.dig("items", 0, "product", "price"), data.dig("items", 0, "product", "salePrice"), data.dig("items", 0, "lineTotal") ]
    assert_equal [ 20.0, 2.0, 22.0 ], data.values_at("subtotal", "deliveryFee", "total")
  end

  test "check charges delivery below 25 KWD" do
    post cart_check_url, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 1 } ] }

    assert_equal [ 12.5, 2.0, 14.5 ], response.parsed_body["data"].values_at("subtotal", "deliveryFee", "total")
  end

  test "check reports unavailable products and leaves them out of the totals" do
    post cart_check_url, as: :json, params: { items: [
      { slug: CHOCOLATE, quantity: 2 },
      { slug: "cuddly-teddy-bear-classic", quantity: 1 },
      { slug: "hidden-product", quantity: 1 },
      { slug: "no-such-product", quantity: 1 }
    ] }

    assert_equal [ CHOCOLATE ], response.parsed_body.dig("data", "items").map { |item| item.dig("product", "slug") }
    assert_equal %w[ cuddly-teddy-bear-classic hidden-product no-such-product ], response.parsed_body.dig("data", "unavailable")
    assert_equal 25.0, response.parsed_body.dig("data", "total")
  end

  test "check lowers a quantity above the stock" do
    post cart_check_url, as: :json, params: { items: [ { slug: GIFT_SET, quantity: 10 } ] }

    assert_equal 6, response.parsed_body.dig("data", "items", 0, "quantity")
  end

  test "check ignores any price sent from the browser" do
    post cart_check_url, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 1, price: 0.001, lineTotal: 0.001 } ] }

    assert_equal 12.5, response.parsed_body.dig("data", "items", 0, "lineTotal")
    assert_equal 14.5, response.parsed_body.dig("data", "total")
  end

  test "check accepts a single item sent without a list" do
    post cart_check_url, as: :json, params: { items: { slug: CHOCOLATE, quantity: 2 } }

    assert_response :success
    assert_equal 25.0, response.parsed_body.dig("data", "total")
  end

  # ---------- Empty and badly shaped carts ----------

  test "check returns an empty cart for a missing or badly shaped list" do
    [ {}, { items: [] }, { items: nil }, { items: "abc" }, { items: [ 1, 2 ] }, { items: 5 }, { items: [ "junk" ] } ].each do |params|
      post cart_check_url, as: :json, params: params

      assert_response :success, "params: #{params.inspect}"
      assert_equal(
        { "items" => [], "unavailable" => [], "subtotal" => 0.0, "deliveryFee" => 0.0, "total" => 0.0 },
        response.parsed_body["data"],
        "params: #{params.inspect}"
      )
    end
  end

  # ---------- Signing in ----------

  test "check works without signing in, even with an invalid token" do
    [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
      post cart_check_url, headers: headers, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 1 } ] }

      assert_response :success
      assert_equal 14.5, response.parsed_body.dig("data", "total")
    end
  end

  test "check works the same when signed in" do
    post cart_check_url, headers: bearer("layla-phone-token"), as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 1 } ] }

    assert_response :success
    assert_equal 14.5, response.parsed_body.dig("data", "total")
  end

  test "check saves nothing" do
    assert_no_difference [ -> { Product.sum(:stock) }, -> { Favorite.count }, -> { Address.count } ] do
      post cart_check_url, as: :json, params: { items: [ { slug: CHOCOLATE, quantity: 2 } ] }
    end
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def product_json(name)
      JSON.parse(ProductSerializer.new.serialize(products(name)).to_json)
    end
end
