require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  GIFT_SET = "forever-yours-gift-set"

  # ---------- Listing a product's reviews ----------

  test "index returns the reviews in the API format" do
    get product_reviews_url(GIFT_SET)

    assert_response :success
    assert_equal(
      [
        {
          "name" => "Layla Al-Sabah",
          "rating" => 5,
          "comment" => "Delivered on time for our anniversary. The box looks beautiful.",
          "createdAt" => reviews(:layla_gift_set).created_at.as_json
        }
      ],
      response.parsed_body["data"]
    )
  end

  test "index works without signing in, even with an invalid token" do
    [ {}, bearer("not-a-real-token") ].each do |headers|
      get product_reviews_url(GIFT_SET), headers: headers

      assert_response :success
    end
  end

  test "index shows a fallback name for a reviewer without one" do
    users(:layla).update!(full_name: nil)

    get product_reviews_url(GIFT_SET)

    assert_equal "Giftie customer", response.parsed_body.dig("data", 0, "name")
  end

  test "index returns the average, count and star breakdown" do
    ReviewService.new.create(deliver(orders(:omar_on_the_way)), products(:gift_set), { rating: 3 })

    get product_reviews_url(GIFT_SET)

    assert_equal(
      { "page" => 1, "perPage" => 10, "totalCount" => 2, "totalPages" => 1, "ratingAverage" => 4.0,
        "breakdown" => { "5" => 1, "4" => 0, "3" => 1, "2" => 0, "1" => 0 } },
      response.parsed_body["meta"]
    )
  end

  test "index lists the newest reviews first, ten per page" do
    add_reviews(products(:gift_set), 11)

    get product_reviews_url(GIFT_SET)
    first_page = response.parsed_body["data"]

    get product_reviews_url(GIFT_SET), params: { page: 2 }
    second_page = response.parsed_body["data"]

    assert_equal 10, first_page.size
    assert_equal [ "Reviewer 11", "Reviewer 10" ], first_page.first(2).pluck("name")
    assert_equal [ "Reviewer 1", "Layla Al-Sabah" ], second_page.pluck("name")
    assert_equal [ 2, 12, 2 ], response.parsed_body["meta"].values_at("page", "totalCount", "totalPages")
  end

  test "index treats a missing or bad page as page 1" do
    [ nil, "0", "-3", "abc" ].each do |page|
      get product_reviews_url(GIFT_SET), params: { page: page }

      assert_equal 1, response.parsed_body.dig("meta", "page"), "page: #{page.inspect}"
    end
  end

  test "index returns an empty list for a product without reviews" do
    get product_reviews_url("cuddly-teddy-bear-classic")

    assert_equal [], response.parsed_body["data"]
    assert_equal [ 0, 0, 0.0 ], response.parsed_body["meta"].values_at("totalCount", "totalPages", "ratingAverage")
  end

  test "index of a hidden or unknown product is not found" do
    [ "hidden-product", "no-such-product" ].each do |slug|
      get product_reviews_url(slug)

      assert_response :not_found
      assert_equal({ "error" => { "code" => "not_found", "message" => "Product not found" } }, response.parsed_body)
    end
  end

  test "index takes the same number of queries however many reviews there are" do
    add_reviews(products(:gift_set), 5)

    assert_queries_count(4) { get product_reviews_url(GIFT_SET) }
  end

  # ---------- My review ----------

  test "show returns my review and that I can review" do
    get product_review_url(GIFT_SET), headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal 5, response.parsed_body.dig("data", "review", "rating")
    assert_equal true, response.parsed_body.dig("data", "canReview")
  end

  test "show returns no review for a customer who has not bought the product" do
    get product_review_url(GIFT_SET), headers: bearer(SessionService.new.start(users(:omar)))

    assert_equal({ "review" => nil, "canReview" => false }, response.parsed_body["data"])
  end

  test "show tells a buyer without a review that they can write one" do
    token = SessionService.new.start(deliver(orders(:omar_on_the_way)))

    get product_review_url(GIFT_SET), headers: bearer(token)

    assert_equal({ "review" => nil, "canReview" => true }, response.parsed_body["data"])
  end

  # ---------- Writing a review ----------

  test "create saves a buyer's review and updates the product" do
    token = SessionService.new.start(deliver(orders(:omar_on_the_way)))

    post product_review_url(GIFT_SET), headers: bearer(token), as: :json, params: { rating: 3, comment: "Nice, but small." }

    assert_response :created
    assert_equal [ "Giftie customer", 3, "Nice, but small." ], response.parsed_body["data"].values_at("name", "rating", "comment")
    assert_equal [ BigDecimal("4.0"), 2 ], products(:gift_set).reload.values_at(:rating_average, :reviews_count)
  end

  test "create ignores fields the customer must not set" do
    token = SessionService.new.start(deliver(orders(:omar_on_the_way)))

    post product_review_url(GIFT_SET), headers: bearer(token), as: :json,
         params: { rating: 4, user_id: users(:layla).id, product_id: products(:chocolate_box).id }

    assert_response :created
    review = Review.order(:id).last
    assert_equal [ users(:omar), products(:gift_set) ], [ review.user, review.product ]
  end

  test "create refuses a customer who has not received the product" do
    assert_no_difference -> { Review.count } do
      post product_review_url(GIFT_SET), headers: bearer(SessionService.new.start(users(:omar))), as: :json, params: { rating: 5 }
    end

    assert_response :forbidden
    assert_equal(
      { "error" => { "code" => "not_a_buyer", "message" => "Only customers who received this product can review it." } },
      response.parsed_body
    )
  end

  test "create refuses a second review of the same product" do
    post product_review_url(GIFT_SET), headers: bearer("layla-phone-token"), as: :json, params: { rating: 1 }

    assert_validation_failed "userId", "has already reviewed this product"
  end

  test "create rejects an invalid rating or comment" do
    token = SessionService.new.start(deliver(orders(:omar_on_the_way)))

    post product_review_url(GIFT_SET), headers: bearer(token), as: :json, params: { rating: 9 }
    assert_validation_failed "rating", "must be in 1..5"

    post product_review_url(GIFT_SET), headers: bearer(token), as: :json, params: { rating: 5, comment: "a" * 1001 }
    assert_validation_failed "comment", "is too long (maximum is 1000 characters)"
  end

  # ---------- Editing a review ----------

  test "update edits my review" do
    patch product_review_url(GIFT_SET), headers: bearer("layla-phone-token"), as: :json, params: { rating: 2, comment: "Changed my mind." }

    assert_response :success
    assert_equal [ 2, "Changed my mind." ], response.parsed_body["data"].values_at("rating", "comment")
    assert_equal [ BigDecimal("2.0"), 1 ], products(:gift_set).reload.values_at(:rating_average, :reviews_count)
  end

  test "update cannot move my review to another user or product" do
    patch product_review_url(GIFT_SET), headers: bearer("layla-phone-token"), as: :json,
          params: { rating: 4, user_id: users(:omar).id, product_id: products(:teddy_bear).id }

    assert_response :success
    review = reviews(:layla_gift_set).reload
    assert_equal [ users(:layla), products(:gift_set), 4 ], [ review.user, review.product, review.rating ]
  end

  test "update without an existing review is not found" do
    patch product_review_url(GIFT_SET), headers: bearer(SessionService.new.start(users(:omar))), as: :json, params: { rating: 5 }

    assert_response :not_found
    assert_equal({ "error" => { "code" => "not_found", "message" => "Review not found" } }, response.parsed_body)
  end

  test "update rejects an invalid rating" do
    patch product_review_url(GIFT_SET), headers: bearer("layla-phone-token"), as: :json, params: { rating: 0 }

    assert_validation_failed "rating", "must be in 1..5"
    assert_equal 5, reviews(:layla_gift_set).reload.rating
  end

  # ---------- Deleting a review ----------

  test "destroy deletes my review and updates the product" do
    delete product_review_url("belgian-chocolate-box"), headers: bearer("layla-phone-token")

    assert_response :no_content
    assert_empty response.body
    assert_not Review.exists?(user: users(:layla), product: products(:chocolate_box))
    assert_equal [ BigDecimal("0.0"), 0 ], products(:chocolate_box).reload.values_at(:rating_average, :reviews_count)
  end

  test "destroy when there is no review still succeeds" do
    delete product_review_url(GIFT_SET), headers: bearer(SessionService.new.start(users(:omar)))

    assert_response :no_content
    assert Review.exists?(reviews(:layla_gift_set).id)
  end

  # ---------- Signing in ----------

  test "my review actions without a valid token are refused and change nothing" do
    requests = [
      ->(headers) { get product_review_url(GIFT_SET), headers: headers },
      ->(headers) { post product_review_url(GIFT_SET), headers: headers, as: :json, params: { rating: 5 } },
      ->(headers) { patch product_review_url(GIFT_SET), headers: headers, as: :json, params: { rating: 1 } },
      ->(headers) { delete product_review_url(GIFT_SET), headers: headers }
    ]

    requests.each do |request|
      [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
        request.call(headers)

        assert_response :unauthorized
        assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
      end
    end

    assert_equal 5, reviews(:layla_gift_set).reload.rating
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def deliver(order)
      order.update!(status: "delivered")
      order.user
    end

    # Adds reviews directly, skipping the buyer rule, to fill a product's review list.
    # Each one is newer than the last, so "Reviewer #{count}" is the newest.
    def add_reviews(product, count)
      count.times do |n|
        user = User.create!(mobile: "6900#{format('%04d', n)}", full_name: "Reviewer #{n + 1}")
        Review.create!(user: user, product: product, rating: 5, created_at: (count - n).minutes.ago)
      end
      product.update_columns(reviews_count: product.reviews.count)
    end

    def assert_validation_failed(key, message)
      assert_response :unprocessable_content
      assert_equal "validation_failed", response.parsed_body.dig("error", "code")
      assert_includes response.parsed_body.dig("error", "details", key), message
    end
end
