require "test_helper"

class AddressTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with all the required fields" do
    assert build_address.valid?
  end

  test "fixtures are valid" do
    Address.find_each do |address|
      assert address.valid?, "#{address.id}: #{address.errors.full_messages.to_sentence}"
    end
  end

  test "requires a user" do
    assert_invalid build_address(user: nil), :user, :blank
  end

  test "belongs to its user only" do
    assert_equal [ addresses(:layla_home), addresses(:layla_work) ].sort, users(:layla).addresses.sort
    assert_equal [ addresses(:omar_home) ], users(:omar).addresses.to_a
    assert_empty users(:blocked).addresses
  end

  # ---------- Address type ----------

  test "accepts Home, Work and Other" do
    %w[ Home Work Other ].each do |address_type|
      assert build_address(address_type: address_type).valid?, "expected #{address_type} to be valid"
    end
  end

  test "rejects any other address type" do
    [ nil, "", "home", "Villa", "Office" ].each do |address_type|
      assert_invalid build_address(address_type: address_type), :address_type, :inclusion
    end
  end

  # ---------- Address, block and area, city ----------

  test "requires the address, block and area, and city" do
    %i[ address block_area city ].each do |field|
      assert_invalid build_address(field => nil), field, :blank
      assert_invalid build_address(field => "   "), field, :blank
    end
  end

  test "requires at least 5 characters in the address" do
    assert build_address(address: "St 12").valid?
    assert_invalid build_address(address: "St 1"), :address, :too_short
  end

  test "requires at least 3 characters in the block and area, and city" do
    %i[ block_area city ].each do |field|
      assert build_address(field => "abc").valid?, "expected 3 characters to be valid for #{field}"
      assert_invalid build_address(field => "ab"), field, :too_short
    end
  end

  test "limits the address to 255 characters" do
    assert build_address(address: "a" * 255).valid?
    assert_invalid build_address(address: "a" * 256), :address, :too_long
  end

  test "limits the block and area, and city to 100 characters, not bytes" do
    %i[ block_area city ].each do |field|
      assert build_address(field => "ب" * 100).valid?, "expected 100 Arabic letters to be valid for #{field}"
      assert_invalid build_address(field => "a" * 101), field, :too_long
    end
  end

  test "trims and collapses spaces in the address, block and area, and city" do
    address = build_address(address: "  Street 12,\n  House 4 ", block_area: " Block 5,\tSalmiya", city: "Kuwait   City ")

    assert_equal "Street 12, House 4", address.address
    assert_equal "Block 5, Salmiya", address.block_area
    assert_equal "Kuwait City", address.city
  end

  test "does not count spaces toward the minimum length" do
    assert_invalid build_address(address: "  St 1  "), :address, :too_short
  end

  # ---------- Default ----------

  test "is not the default unless set" do
    assert_not Address.new.is_default
  end

  test "rejects an empty default flag" do
    assert_invalid build_address(is_default: nil), :is_default, :inclusion
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects an unknown address type" do
    assert_raises(ActiveRecord::CheckViolation) { build_address(address_type: "Villa").save(validate: false) }
  end

  test "database rejects a second default address for the same user" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_address(user: users(:layla), is_default: true).save(validate: false)
    end
  end

  test "database allows one default address for each user" do
    assert build_address(user: users(:blocked), is_default: true).save
  end

  test "database allows many addresses that are not the default" do
    assert build_address(user: users(:layla), is_default: false).save
    assert build_address(user: users(:layla), is_default: false).save
  end

  test "database rejects a missing required field" do
    assert_raises(ActiveRecord::NotNullViolation) { build_address(city: nil).save(validate: false) }
  end

  test "database deletes the addresses when the user is deleted" do
    address_ids = users(:layla).addresses.ids

    users(:layla).delete

    assert_empty Address.where(id: address_ids)
    assert Address.exists?(addresses(:omar_home).id)
  end

  private
    def build_address(**attributes)
      Address.new({
        user: users(:omar), address_type: "Home", address: "Street 12, House 4",
        block_area: "Block 5, Salmiya", city: "Kuwait City"
      }.merge(attributes))
    end

    def assert_invalid(address, attribute, error_type)
      assert_not address.valid?, "expected #{attribute} #{error_type} error, but the address was valid"
      assert address.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{address.errors.details[attribute]}"
    end
end
