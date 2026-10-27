require "test_helper"

class LoginCodeServiceTest < ActiveSupport::TestCase
  MOBILE = "50000001"

  setup do
    @service = LoginCodeService.new
  end

  # ---------- issue ----------

  test "issue returns a code of the configured length" do
    code = @service.issue(MOBILE)

    assert_match(/\A\d{#{LoginCode::CODE_LENGTH}}\z/, code)
  end

  test "issue keeps leading zeros" do
    with_random_number(427) do
      assert_equal "0427", @service.issue(MOBILE)
    end
  end

  test "issue saves a code for the mobile number" do
    assert_difference -> { LoginCode.where(mobile: MOBILE).count }, 1 do
      @service.issue(MOBILE)
    end
  end

  test "issue stores only a hash of the code, never the code itself" do
    code = @service.issue(MOBILE)
    saved = LoginCode.last

    assert_equal 64, saved.code_digest.length
    assert_not_equal code, saved.code_digest
    assert_not_includes saved.attributes.values.map(&:to_s), code
  end

  test "issue gives the same code the same hash only within the app" do
    with_random_number(1234) do
      @service.issue(MOBILE)
      @service.issue("60000002")
    end

    first, second = LoginCode.last(2)
    assert_equal first.code_digest, second.code_digest
    assert_not_equal Digest::SHA256.hexdigest("1234"), first.code_digest, "the hash must be keyed with the app secret"
  end

  test "issue sets the code to expire after the configured lifetime" do
    freeze_time do
      @service.issue(MOBILE)

      assert_equal LoginCode::LIFETIME.from_now, LoginCode.last.expires_at
    end
  end

  test "issue starts a code with no attempts and unused" do
    @service.issue(MOBILE)

    assert_equal 0, LoginCode.last.attempts
    assert_nil LoginCode.last.consumed_at
  end

  test "issue accepts a mobile number with spaces or dashes" do
    @service.issue(" 5000 0001 ")
    @service.issue("5000-0001")

    assert_equal 2, LoginCode.where(mobile: MOBILE).count
  end

  test "issue rejects a badly formatted mobile number" do
    assert_raises(ActiveRecord::RecordInvalid) { @service.issue("40000000") }
  end

  # ---------- verify ----------

  test "verify accepts the right code and marks it as used" do
    code = @service.issue(MOBILE)

    assert @service.verify(MOBILE, code)
    assert_not_nil LoginCode.last.consumed_at
  end

  test "verify finds the code when the mobile number has spaces or dashes" do
    code = @service.issue(MOBILE)

    assert @service.verify("5000 0001", code)
  end

  test "verify rejects a wrong code and counts the attempt" do
    code = @service.issue(MOBILE)

    assert_not @service.verify(MOBILE, wrong_code(code))
    assert_equal 1, LoginCode.last.attempts
    assert_nil LoginCode.last.consumed_at
  end

  test "verify rejects a code that was already used" do
    code = @service.issue(MOBILE)
    @service.verify(MOBILE, code)

    assert_not @service.verify(MOBILE, code)
  end

  test "verify rejects an expired code, even when typed correctly" do
    code = @service.issue(MOBILE)

    travel LoginCode::LIFETIME + 1.second do
      assert_not @service.verify(MOBILE, code)
    end
  end

  test "verify stops accepting a code after the maximum wrong attempts" do
    code = @service.issue(MOBILE)
    LoginCode::MAX_ATTEMPTS.times { @service.verify(MOBILE, wrong_code(code)) }

    assert_not @service.verify(MOBILE, code)
    assert_equal LoginCode::MAX_ATTEMPTS, LoginCode.last.attempts
  end

  test "verify still accepts the right code with one attempt left" do
    code = @service.issue(MOBILE)
    (LoginCode::MAX_ATTEMPTS - 1).times { @service.verify(MOBILE, wrong_code(code)) }

    assert @service.verify(MOBILE, code)
  end

  test "verify only accepts the newest code for a mobile number" do
    with_random_number(1111) { @service.issue(MOBILE) }
    travel 1.second
    with_random_number(2222) { @service.issue(MOBILE) }

    assert_not @service.verify(MOBILE, "1111")
    assert @service.verify(MOBILE, "2222")
  end

  test "verify counts a wrong attempt on the newest code only" do
    with_random_number(1111) { @service.issue(MOBILE) }
    travel 1.second
    with_random_number(2222) { @service.issue(MOBILE) }

    @service.verify(MOBILE, "1111")

    old_row, new_row = LoginCode.where(mobile: MOBILE).order(:created_at).to_a
    assert_equal 0, old_row.attempts
    assert_equal 1, new_row.attempts
  end

  test "verify does not accept another mobile number's code" do
    code = @service.issue(MOBILE)

    assert_not @service.verify("60000002", code)
  end

  test "verify returns false when no code exists for the mobile number" do
    assert_not @service.verify(MOBILE, "1234")
  end

  test "verify returns false for a blank code" do
    @service.issue(MOBILE)

    assert_not @service.verify(MOBILE, "")
    assert_not @service.verify(MOBILE, nil)
  end

  private
    def wrong_code(code)
      code == "0000" ? "1111" : "0000"
    end

    # Makes SecureRandom return a fixed number inside the block. The real method
    # comes from Random::Formatter, so removing the override restores it.
    def with_random_number(value)
      SecureRandom.define_singleton_method(:random_number) { |*| value }
      yield
    ensure
      SecureRandom.singleton_class.remove_method(:random_number)
    end
end
