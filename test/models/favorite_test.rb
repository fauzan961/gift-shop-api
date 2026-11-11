require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "is valid with a user and a product" do
    assert Favorite.new(user: users(:omar), product: products(:teddy_bear)).valid?
  end

  test "fixtures are valid" do
    Favorite.find_each do |favorite|
      assert favorite.valid?, "#{favorite.id}: #{favorite.errors.full_messages.to_sentence}"
    end
  end

  test "requires a user and a product" do
    favorite = Favorite.new

    assert_not favorite.valid?
    assert favorite.errors.of_kind?(:user, :blank)
    assert favorite.errors.of_kind?(:product, :blank)
  end

  test "rejects the same product twice for the same user" do
    favorite = Favorite.new(user: users(:layla), product: products(:gift_set))

    assert_not favorite.valid?
    assert favorite.errors.of_kind?(:product_id, :taken)
  end

  test "allows different users to favorite the same product" do
    assert_equal 2, Favorite.where(product: products(:gift_set)).count
  end

  test "belongs to its user only" do
    assert_equal [ favorites(:layla_gift_set), favorites(:layla_teddy_bear) ].sort, users(:layla).favorites.sort
    assert_equal [ favorites(:omar_gift_set) ], users(:omar).favorites.to_a
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects the same product twice for the same user" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Favorite.new(user: users(:layla), product: products(:gift_set)).save(validate: false)
    end
  end

  test "database deletes the favorites when the user is deleted" do
    users(:layla).delete

    assert_empty Favorite.where(user_id: users(:layla).id)
    assert Favorite.exists?(favorites(:omar_gift_set).id)
  end

  test "database deletes the favorites when the product is deleted" do
    Favorite.create!(user: users(:omar), product: products(:chocolate_box))

    products(:chocolate_box).delete

    assert_empty Favorite.where(product_id: products(:chocolate_box).id)
    assert_equal 3, Favorite.count
  end
end
