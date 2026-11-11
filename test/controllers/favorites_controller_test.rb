require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  # ---------- Listing ----------

  test "index lists the user's favorite products, newest first" do
    get favorites_url, headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set ], response.parsed_body["data"].pluck("slug")
  end

  test "index returns each product in the same format as the product list" do
    get favorites_url, headers: bearer("layla-phone-token")

    assert_equal JSON.parse(ProductSerializer.new.serialize(products(:teddy_bear)).to_json),
                 response.parsed_body["data"].first
  end

  test "index never shows another user's favorites" do
    get favorites_url, headers: bearer(SessionService.new.start(users(:omar)))

    assert_equal %w[ forever-yours-gift-set ], response.parsed_body["data"].pluck("slug")
  end

  test "index leaves out products that have been hidden" do
    Favorite.create!(user: users(:layla), product: products(:hidden_product))

    get favorites_url, headers: bearer("layla-phone-token")

    assert_not_includes response.parsed_body["data"].pluck("slug"), "hidden-product"
  end

  test "index returns an empty list for a user without favorites" do
    get favorites_url, headers: bearer(SessionService.new.start(User.create!(mobile: "69999999")))

    assert_response :success
    assert_equal({ "data" => [] }, response.parsed_body)
  end

  test "index takes the same number of queries however many favorites there are" do
    Favorite.create!(user: users(:layla), product: products(:chocolate_box))
    get favorites_url, headers: bearer("layla-phone-token")

    assert_queries_count(7) { get favorites_url, headers: bearer("layla-phone-token") }
  end

  # ---------- Adding ----------

  test "create adds the product to the user's favorites" do
    assert_difference -> { users(:layla).favorites.count }, 1 do
      post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: { slug: "belgian-chocolate-box" }
    end

    assert_response :no_content
    assert_empty response.body
    assert users(:layla).favorites.exists?(product: products(:chocolate_box))
  end

  test "create puts the new favorite first in the list" do
    post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: { slug: "belgian-chocolate-box" }

    get favorites_url, headers: bearer("layla-phone-token")
    assert_equal "belgian-chocolate-box", response.parsed_body["data"].first["slug"]
  end

  test "create of a product that is already a favorite changes nothing" do
    assert_no_difference -> { Favorite.count } do
      post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: { slug: "forever-yours-gift-set" }
      post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: { slug: "forever-yours-gift-set" }
    end

    assert_response :no_content
  end

  test "create accepts the slug in any letter case" do
    post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: { slug: "Belgian-Chocolate-Box" }

    assert_response :no_content
    assert users(:layla).favorites.exists?(product: products(:chocolate_box))
  end

  test "create of a hidden, unknown or missing product is not found" do
    [ { slug: "hidden-product" }, { slug: "no-such-product" }, {} ].each do |params|
      assert_no_difference -> { Favorite.count } do
        post favorites_url, headers: bearer("layla-phone-token"), as: :json, params: params
      end

      assert_response :not_found, "params: #{params.inspect}"
      assert_equal "not_found", response.parsed_body.dig("error", "code")
    end
  end

  # ---------- Removing ----------

  test "destroy removes the product from the user's favorites" do
    delete favorite_url("forever-yours-gift-set"), headers: bearer("layla-phone-token")

    assert_response :no_content
    assert_empty response.body
    assert_not Favorite.exists?(favorites(:layla_gift_set).id)
  end

  test "destroy leaves other users' favorites alone" do
    delete favorite_url("forever-yours-gift-set"), headers: bearer("layla-phone-token")

    assert Favorite.exists?(favorites(:omar_gift_set).id)
    assert Favorite.exists?(favorites(:layla_teddy_bear).id)
  end

  test "destroy of a product that is not a favorite changes nothing" do
    [ "belgian-chocolate-box", "no-such-product" ].each do |slug|
      assert_no_difference -> { Favorite.count } do
        delete favorite_url(slug), headers: bearer("layla-phone-token")
      end

      assert_response :no_content
    end
  end

  test "destroy still removes a product that has been hidden since" do
    favorite = Favorite.create!(user: users(:layla), product: products(:hidden_product))

    delete favorite_url("hidden-product"), headers: bearer("layla-phone-token")

    assert_not Favorite.exists?(favorite.id)
  end

  # ---------- Signing in ----------

  test "every action without a valid token is refused and changes nothing" do
    requests = [
      ->(headers) { get favorites_url, headers: headers },
      ->(headers) { post favorites_url, headers: headers, as: :json, params: { slug: "belgian-chocolate-box" } },
      ->(headers) { delete favorite_url("forever-yours-gift-set"), headers: headers }
    ]

    requests.each do |request|
      [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
        assert_no_difference -> { Favorite.count } do
          request.call(headers)
        end

        assert_response :unauthorized
        assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
      end
    end
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
