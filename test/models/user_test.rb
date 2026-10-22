require "test_helper"

class UserTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with only a mobile number" do
    assert build_user.valid?
  end

  test "fixtures are valid" do
    User.find_each do |user|
      assert user.valid?, "#{user.mobile}: #{user.errors.full_messages.to_sentence}"
    end
  end

  # ---------- Mobile ----------

  test "requires a mobile number" do
    assert_invalid build_user(mobile: nil), :mobile, :blank
    assert_invalid build_user(mobile: "   "), :mobile, :blank
  end

  test "requires a unique mobile number" do
    assert_invalid build_user(mobile: users(:layla).mobile), :mobile, :taken
  end

  test "accepts mobile numbers starting with 5, 6 or 9" do
    %w[ 51234567 61234567 91234567 ].each do |mobile|
      assert build_user(mobile: mobile).valid?, "expected #{mobile} to be valid"
    end
  end

  test "rejects mobile numbers that are not 8 digits starting with 5, 6 or 9" do
    %w[ 41234567 01234567 5123456 512345678 5123456a +9655123 96551234567 ].each do |mobile|
      assert_invalid build_user(mobile: mobile), :mobile, :invalid
    end
  end

  test "removes spaces and dashes from the mobile number" do
    assert_equal "51234567", build_user(mobile: " 5123 4567 ").mobile
    assert_equal "51234567", build_user(mobile: "5123-4567").mobile
  end

  # ---------- Full name ----------

  test "does not require a full name" do
    assert build_user(full_name: nil).valid?
  end

  test "limits the full name to 100 characters, not bytes" do
    assert build_user(full_name: "a" * 100).valid?
    assert build_user(full_name: "ل" * 100).valid?
    assert_invalid build_user(full_name: "a" * 101), :full_name, :too_long
  end

  test "trims and collapses spaces in the full name" do
    assert_equal "Layla Al-Sabah", build_user(full_name: "  Layla   Al-Sabah ").full_name
    assert_equal "ليلى الصباح", build_user(full_name: " ليلى\t الصباح ").full_name
  end

  test "stores a blank full name as nil" do
    assert_nil build_user(full_name: "   ").full_name
  end

  # ---------- Email ----------

  test "does not require an email" do
    assert build_user(email: nil).valid?
  end

  test "allows many users without an email" do
    assert_nil users(:omar).email
    assert build_user(email: "   ").save
  end

  test "requires a unique email, ignoring capitals" do
    assert_invalid build_user(email: "LAYLA@Mail.com"), :email, :taken
  end

  test "lowercases and trims the email" do
    assert_equal "sara@mail.com", build_user(email: "  Sara@Mail.COM ").email
  end

  test "stores a blank email as nil" do
    assert_nil build_user(email: "   ").email
  end

  test "rejects badly formatted emails" do
    [ "sara", "sara@", "@mail.com", "sara mail@mail.com", "sara@@mail.com" ].each do |email|
      assert_invalid build_user(email: email), :email, :invalid
    end
  end

  test "limits the email to 255 characters" do
    domain = "@example.com"
    assert build_user(email: "a" * (255 - domain.length) + domain).valid?
    assert_invalid build_user(email: "a" * (256 - domain.length) + domain), :email, :too_long
  end

  # ---------- Birthday ----------

  test "does not require a birthday" do
    assert build_user(birthday: nil).valid?
  end

  test "allows a birthday of today but not in the future" do
    assert build_user(birthday: Date.current).valid?
    assert_invalid build_user(birthday: Date.current + 1), :birthday, "can't be in the future"
  end

  test "measures today in Kuwait time for the birthday" do
    # 22:00 UTC on 6 October is already 01:00 on 7 October in Kuwait.
    travel_to Time.utc(2026, 10, 6, 22, 0) do
      assert build_user(birthday: Date.new(2026, 10, 7)).valid?
      assert_invalid build_user(birthday: Date.new(2026, 10, 8)), :birthday, "can't be in the future"
    end
  end

  # ---------- Preferences and active ----------

  test "defaults the preferences to match the account page" do
    user = User.new

    assert user.order_sms
    assert user.occasion_reminders
    assert_not user.offers_email
  end

  test "defaults active to true" do
    assert User.new.active
  end

  test "rejects empty preference and active flags" do
    %i[ order_sms occasion_reminders offers_email active ].each do |flag|
      assert_invalid build_user(flag => nil), flag, :inclusion
    end
  end

  test "allows the preference and active flags to be true or false" do
    assert build_user(order_sms: false, occasion_reminders: false, offers_email: true, active: false).valid?
  end

  # ---------- Scopes ----------

  test "active leaves out blocked users" do
    assert_includes User.active, users(:layla)
    assert_not_includes User.active, users(:blocked)
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a badly formatted mobile number" do
    assert_raises(ActiveRecord::CheckViolation) { build_user(mobile: "41234567").save(validate: false) }
  end

  test "database rejects a duplicate mobile number" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_user(mobile: users(:layla).mobile).save(validate: false)
    end
  end

  test "database rejects a duplicate email in different capitals" do
    # Plain SQL skips the model's lowercasing, so this tests the index itself.
    assert_raises(ActiveRecord::RecordNotUnique) do
      User.connection.execute(<<~SQL)
        INSERT INTO users (mobile, email, created_at, updated_at)
        VALUES ('51234567', 'LAYLA@MAIL.COM', now(), now())
      SQL
    end
  end

  test "database rejects a missing mobile number" do
    assert_raises(ActiveRecord::NotNullViolation) { build_user(mobile: nil).save(validate: false) }
  end

  private
    def build_user(**attributes)
      User.new({ mobile: "51234567" }.merge(attributes))
    end

    def assert_invalid(user, attribute, error_type)
      assert_not user.valid?, "expected #{attribute} #{error_type} error, but the user was valid"
      assert user.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{user.errors.details[attribute]}"
    end
end
