require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a user, product and rating" do
    assert build_review.valid?
  end

  test "fixtures are valid" do
    Review.find_each do |review|
      assert review.valid?, "#{review.id}: #{review.errors.full_messages.to_sentence}"
    end
  end

  test "requires a user and a product" do
    review = build_review(user: nil, product: nil)

    assert_not review.valid?
    assert review.errors.of_kind?(:user, :blank)
    assert review.errors.of_kind?(:product, :blank)
  end

  test "belongs to its user and product" do
    assert_equal [ reviews(:layla_chocolate_box), reviews(:layla_gift_set) ].sort, users(:layla).reviews.sort
    assert_equal [ reviews(:layla_gift_set) ], products(:gift_set).reviews.to_a
    assert_empty users(:omar).reviews
  end

  # ---------- Rating ----------

  test "accepts a rating from 1 to 5" do
    (1..5).each { |rating| assert build_review(rating: rating).valid?, "rating: #{rating}" }
  end

  test "rejects a rating outside 1 to 5 or not a whole number" do
    assert_invalid build_review(rating: 0), :rating, :in
    assert_invalid build_review(rating: 6), :rating, :in
    assert_invalid build_review(rating: "4.5"), :rating, :not_an_integer
    assert_invalid build_review(rating: nil), :rating, :not_a_number
  end

  # ---------- Comment ----------

  test "does not require a comment" do
    assert build_review(comment: nil).valid?
  end

  test "keeps line breaks in the comment but trims the ends" do
    assert_equal "Delicious!\nWill buy again.", build_review(comment: "  Delicious!\nWill buy again. \n").comment
  end

  test "stores a blank comment as nil" do
    assert_nil build_review(comment: "  \n ").comment
  end

  test "limits the comment to 1000 characters" do
    assert build_review(comment: "ح" * 1000).valid?
    assert_invalid build_review(comment: "a" * 1001), :comment, :too_long
  end

  # ---------- One review per product ----------

  test "allows only one review per user for each product" do
    review = build_review(user: users(:layla), product: products(:gift_set))

    assert_invalid review, :user_id, :taken
    assert_includes review.errors.full_messages, "User has already reviewed this product"
  end

  test "allows the same user to review different products" do
    assert build_review(user: users(:layla), product: products(:teddy_bear)).valid?
  end

  test "allows different users to review the same product" do
    assert build_review(user: users(:omar), product: products(:gift_set)).valid?
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a rating outside 1 to 5" do
    [ 0, 6 ].each do |rating|
      assert_raises(ActiveRecord::CheckViolation) { build_review(rating: rating).save(validate: false) }
    end
  end

  test "database rejects a second review of the same product by the same user" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_review(user: users(:layla), product: products(:gift_set)).save(validate: false)
    end
  end

  test "database deletes the reviews when the product is deleted" do
    review_id = reviews(:layla_gift_set).id

    products(:gift_set).delete

    assert_not Review.exists?(review_id)
    assert Review.exists?(reviews(:layla_chocolate_box).id)
  end

  test "database deletes the reviews when the user is deleted" do
    Order.where(user: users(:layla)).delete_all

    users(:layla).delete

    assert_empty Review.where(user_id: users(:layla).id)
  end

  private
    def build_review(**attributes)
      Review.new({ user: users(:omar), product: products(:teddy_bear), rating: 5, comment: "Lovely gift." }.merge(attributes))
    end

    def assert_invalid(review, attribute, error_type)
      assert_not review.valid?, "expected #{attribute} #{error_type} error, but the review was valid"
      assert review.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{review.errors.details[attribute]}"
    end
end
