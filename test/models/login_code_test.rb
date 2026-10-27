require "test_helper"

class LoginCodeTest < ActiveSupport::TestCase
  # ---------- Validations ----------

  test "is valid with a mobile number, digest and expiry" do
    assert build_login_code.valid?
  end

  test "requires a well formatted mobile number" do
    %w[ 40000000 5000000 +9655000 ].each do |mobile|
      assert_invalid build_login_code(mobile: mobile), :mobile, :invalid
    end
    assert_invalid build_login_code(mobile: nil), :mobile, :invalid
  end

  test "removes spaces and dashes from the mobile number" do
    assert_equal "50000001", build_login_code(mobile: " 5000 0001 ").mobile
    assert_equal "50000001", build_login_code(mobile: "5000-0001").mobile
  end

  test "cleans the mobile number in lookups too" do
    build_login_code.save!

    assert_equal 1, LoginCode.where(mobile: "5000 0001").count
  end

  test "requires a 64 character digest" do
    assert_invalid build_login_code(code_digest: nil), :code_digest, :blank
    assert_invalid build_login_code(code_digest: "a" * 63), :code_digest, :wrong_length
    assert_invalid build_login_code(code_digest: "a" * 65), :code_digest, :wrong_length
  end

  test "requires an expiry time" do
    assert_invalid build_login_code(expires_at: nil), :expires_at, :blank
  end

  test "requires attempts to be a whole number of 0 or more" do
    assert_invalid build_login_code(attempts: -1), :attempts, :greater_than_or_equal_to
    assert_invalid build_login_code(attempts: 1.5), :attempts, :not_an_integer
    assert_invalid build_login_code(attempts: nil), :attempts, :not_a_number
  end

  test "defaults attempts to 0" do
    assert_equal 0, LoginCode.new.attempts
  end

  # ---------- usable? ----------

  test "is usable when unused, unexpired and under the attempt limit" do
    assert build_login_code.usable?
  end

  test "is not usable once used" do
    assert_not build_login_code(consumed_at: Time.current).usable?
  end

  test "is not usable once expired" do
    assert_not build_login_code(expires_at: 1.second.ago).usable?
  end

  test "is usable with one attempt left, but not at the limit" do
    assert build_login_code(attempts: LoginCode::MAX_ATTEMPTS - 1).usable?
    assert_not build_login_code(attempts: LoginCode::MAX_ATTEMPTS).usable?
  end

  # ---------- Database rules ----------

  test "database rejects a badly formatted mobile number" do
    assert_raises(ActiveRecord::CheckViolation) { build_login_code(mobile: "40000000").save(validate: false) }
  end

  test "database rejects negative attempts" do
    assert_raises(ActiveRecord::CheckViolation) { build_login_code(attempts: -1).save(validate: false) }
  end

  test "database rejects a missing digest" do
    assert_raises(ActiveRecord::NotNullViolation) { build_login_code(code_digest: nil).save(validate: false) }
  end

  test "database rejects a digest longer than 64 characters" do
    assert_raises(ActiveRecord::ValueTooLong) { build_login_code(code_digest: "a" * 65).save(validate: false) }
  end

  private
    def build_login_code(**attributes)
      LoginCode.new({ mobile: "50000001", code_digest: "a" * 64, expires_at: 5.minutes.from_now }.merge(attributes))
    end

    def assert_invalid(login_code, attribute, error_type)
      assert_not login_code.valid?, "expected #{attribute} #{error_type} error, but the code was valid"
      assert login_code.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{login_code.errors.details[attribute]}"
    end
end
