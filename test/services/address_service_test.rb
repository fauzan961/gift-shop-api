require "test_helper"

class AddressServiceTest < ActiveSupport::TestCase
  ADDRESS = { address_type: "Other", address: "Street 7, House 22", block_area: "Block 2, Rumaithiya", city: "Hawalli" }

  setup do
    @service = AddressService.new
  end

  # ---------- create ----------

  test "create saves the address for the user and returns it" do
    address = @service.create(users(:omar), ADDRESS)

    assert address.persisted?
    assert_equal users(:omar), address.user
    assert_equal "Block 2, Rumaithiya", address.block_area
  end

  test "create makes a user's first address the default, even when not asked" do
    address = @service.create(users(:blocked), ADDRESS.merge(is_default: false))

    assert address.is_default
  end

  test "create does not change the default unless asked" do
    address = @service.create(users(:layla), ADDRESS)

    assert_not address.is_default
    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "create moves the default to a new address when asked" do
    address = @service.create(users(:layla), ADDRESS.merge(is_default: true))

    assert_equal [ address ], defaults(users(:layla))
  end

  test "create leaves other users' defaults alone" do
    @service.create(users(:layla), ADDRESS.merge(is_default: true))

    assert_equal [ addresses(:omar_home) ], defaults(users(:omar))
  end

  test "create saves nothing and keeps the old default when the address is invalid" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @service.create(users(:layla), ADDRESS.merge(city: "ab", is_default: true))
    end

    assert_equal 2, users(:layla).addresses.count
    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "create refuses an address past the limit" do
    (AddressService::MAX_PER_USER - 2).times { @service.create(users(:layla), ADDRESS) }

    error = assert_raises(AddressService::LimitReached) { @service.create(users(:layla), ADDRESS) }

    assert_equal "You can save up to 10 addresses.", error.message
    assert_equal AddressService::MAX_PER_USER, users(:layla).addresses.count
  end

  test "create counts the limit for each user separately" do
    (AddressService::MAX_PER_USER - 2).times { @service.create(users(:layla), ADDRESS) }

    assert @service.create(users(:omar), ADDRESS).persisted?
  end

  # ---------- update ----------

  test "update changes the address" do
    @service.update(addresses(:layla_work), city: "Farwaniya", address_type: "Other")

    assert_equal "Farwaniya", addresses(:layla_work).reload.city
    assert_equal "Other", addresses(:layla_work).address_type
  end

  test "update moves the default to another address" do
    @service.update(addresses(:layla_work), is_default: true)

    assert_equal [ addresses(:layla_work) ], defaults(users(:layla))
  end

  test "update keeps the default when asked to turn it off" do
    @service.update(addresses(:layla_home), is_default: false)

    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "update keeps the default when editing other fields" do
    @service.update(addresses(:layla_home), city: "Farwaniya")

    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "update leaves other users' defaults alone" do
    @service.update(addresses(:layla_work), is_default: true)

    assert_equal [ addresses(:omar_home) ], defaults(users(:omar))
  end

  test "update saves nothing and keeps the old default when the change is invalid" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @service.update(addresses(:layla_work), is_default: true, city: "ab")
    end

    assert_equal "Kuwait City", addresses(:layla_work).reload.city
    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "update uses the saved values, not an out-of-date copy" do
    old_copy = Address.find(addresses(:layla_home).id)
    @service.update(addresses(:layla_work), is_default: true)

    @service.update(old_copy, city: "Farwaniya")

    assert_equal "Farwaniya", addresses(:layla_home).reload.city
    assert_equal [ addresses(:layla_work) ], defaults(users(:layla))
  end

  # ---------- destroy ----------

  test "destroy removes the address" do
    @service.destroy(addresses(:layla_work))

    assert_not Address.exists?(addresses(:layla_work).id)
    assert_equal [ addresses(:layla_home) ], defaults(users(:layla))
  end

  test "destroy makes the oldest remaining address the default when the default is removed" do
    newer = @service.create(users(:layla), ADDRESS)

    @service.destroy(addresses(:layla_home))

    assert_equal [ addresses(:layla_work) ], defaults(users(:layla))
    assert_not newer.reload.is_default
  end

  test "destroy of the last address leaves the user with none" do
    @service.destroy(addresses(:omar_home))

    assert_empty users(:omar).addresses
  end

  test "destroy uses the saved values, not an out-of-date copy" do
    newer = @service.create(users(:layla), ADDRESS)
    old_copy = Address.find(addresses(:layla_home).id)
    @service.update(newer, is_default: true)

    @service.destroy(old_copy)

    assert_not Address.exists?(addresses(:layla_home).id)
    assert_equal [ newer ], defaults(users(:layla))
  end

  test "destroy of an address that is already gone raises not found" do
    old_copy = Address.find(addresses(:layla_work).id)
    addresses(:layla_work).delete

    assert_raises(ActiveRecord::RecordNotFound) { @service.destroy(old_copy) }
  end

  private
    def defaults(user)
      user.addresses.where(is_default: true).to_a
    end
end
