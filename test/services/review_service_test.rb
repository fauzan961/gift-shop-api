require "test_helper"

class ReviewServiceTest < ActiveSupport::TestCase
  setup do
    @service = ReviewService.new
  end

  # ---------- can_review? ----------

  test "can_review? is true only for products in a delivered order" do
    assert @service.can_review?(users(:layla), products(:gift_set))
    assert @service.can_review?(users(:layla), products(:chocolate_box))
    assert_not @service.can_review?(users(:layla), products(:teddy_bear)), "only in an unpaid order"
    assert_not @service.can_review?(users(:omar), products(:gift_set)), "order still on the way"
    assert_not @service.can_review?(users(:blocked), products(:gift_set)), "never ordered"
  end

  test "can_review? becomes true once the order is delivered" do
    orders(:omar_on_the_way).update!(status: "delivered")

    assert @service.can_review?(users(:omar), products(:gift_set))
  end

  # ---------- create ----------

  test "create saves a buyer's review" do
    omar = deliver(orders(:omar_on_the_way))

    review = @service.create(omar, products(:gift_set), { rating: 3, comment: "Nice, but small." })

    assert review.persisted?
    assert_equal [ omar, products(:gift_set), 3, "Nice, but small." ], [ review.user, review.product, review.rating, review.comment ]
  end

  test "create updates the product's average and count" do
    @service.create(deliver(orders(:omar_on_the_way)), products(:gift_set), { rating: 3 })

    assert_rating products(:gift_set), "4.0", 2
  end

  test "create rounds the average to one decimal" do
    @service.create(deliver(orders(:omar_on_the_way)), products(:gift_set), { rating: 4 })
    @service.create(buyer_of(products(:gift_set), mobile: "69999990"), products(:gift_set), { rating: 2 })

    assert_rating products(:gift_set), "3.7", 3
  end

  test "create refuses a customer who has not received the product" do
    [ [ users(:omar), products(:gift_set) ], [ users(:layla), products(:teddy_bear) ], [ users(:blocked), products(:gift_set) ] ].each do |user, product|
      assert_no_difference -> { Review.count } do
        error = assert_raises(ReviewService::NotABuyer) { @service.create(user, product, { rating: 5 }) }
        assert_equal "Only customers who received this product can review it.", error.message
      end
    end
  end

  test "create refuses a second review of the same product" do
    error = assert_raises(ActiveRecord::RecordInvalid) { @service.create(users(:layla), products(:gift_set), { rating: 1 }) }

    assert_includes error.record.errors.full_messages, "User has already reviewed this product"
    assert_equal 5, reviews(:layla_gift_set).reload.rating
  end

  test "create saves nothing when the rating is invalid" do
    omar = deliver(orders(:omar_on_the_way))

    assert_no_difference -> { Review.count } do
      assert_raises(ActiveRecord::RecordInvalid) { @service.create(omar, products(:gift_set), { rating: 9 }) }
    end
    assert_rating products(:gift_set), "4.6", 8
  end

  # ---------- update ----------

  test "update edits the user's review and the product's average" do
    review = @service.update(users(:layla), products(:gift_set), { rating: 2, comment: "Changed my mind." })

    assert_equal [ reviews(:layla_gift_set), 2, "Changed my mind." ], [ review, review.rating, review.comment ]
    assert_rating products(:gift_set), "2.0", 1
  end

  test "update changes only the fields that were sent" do
    @service.update(users(:layla), products(:gift_set), { rating: 4 })

    assert_equal "Delivered on time for our anniversary. The box looks beautiful.", reviews(:layla_gift_set).reload.comment
  end

  test "update can remove the comment" do
    @service.update(users(:layla), products(:gift_set), { comment: nil })

    assert_nil reviews(:layla_gift_set).reload.comment
  end

  test "update of a review that does not exist is not found" do
    assert_raises(ActiveRecord::RecordNotFound) { @service.update(users(:omar), products(:gift_set), { rating: 5 }) }
  end

  test "update saves nothing when the rating is invalid" do
    assert_raises(ActiveRecord::RecordInvalid) { @service.update(users(:layla), products(:gift_set), { rating: 0 }) }

    assert_equal 5, reviews(:layla_gift_set).reload.rating
    assert_rating products(:gift_set), "4.6", 8
  end

  # ---------- destroy ----------

  test "destroy removes the user's review and updates the product" do
    @service.create(deliver(orders(:omar_on_the_way)), products(:gift_set), { rating: 3 })

    @service.destroy(users(:layla), products(:gift_set))

    assert_not Review.exists?(user: users(:layla), product: products(:gift_set))
    assert_rating products(:gift_set), "3.0", 1
  end

  test "destroy of the last review resets the product to no rating" do
    @service.destroy(users(:layla), products(:chocolate_box))

    assert_rating products(:chocolate_box), "0.0", 0
  end

  test "destroy leaves other users' reviews alone" do
    @service.destroy(users(:omar), products(:gift_set))

    assert Review.exists?(reviews(:layla_gift_set).id)
  end

  test "destroy when there is no review changes nothing but still corrects the numbers" do
    assert_no_difference -> { Review.count } do
      @service.destroy(users(:omar), products(:gift_set))
    end

    assert_rating products(:gift_set), "5.0", 1
  end

  private
    def deliver(order)
      order.update!(status: "delivered")
      order.user
    end

    def buyer_of(product, mobile:)
      user = User.create!(mobile: mobile)
      order = user.orders.create!(
        number: "2611190#{mobile.last(4)}", status: "delivered", recipient_name: "Sara", address: "Street 1, House 1",
        block_area: "Block 1", city: "Kuwait City", delivery_date: Date.current, delivery_slot: "09-12",
        payment_method: "knet", subtotal: product.price, delivery_fee: 0, total: product.price
      )
      order.order_items.create!(product: product, product_name_en: product.name_en, unit_price: product.price, quantity: 1, line_total: product.price)
      user
    end

    def assert_rating(product, average, count)
      product.reload
      assert_equal [ BigDecimal(average), count ], [ product.rating_average, product.reviews_count ]
    end
end
