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
    wait_for_resend
    @service.issue("5000-0001")

    assert_equal 2, LoginCode.where(mobile: MOBILE).count
  end

  test "issue rejects a badly formatted mobile number" do
    assert_raises(ActiveRecord::RecordInvalid) { @service.issue("40000000") }
  end

  # ---------- Limits ----------

  test "issue refuses a new code within the resend time" do
    freeze_time do
      @service.issue(MOBILE)
      travel 12.seconds

      error = assert_raises(LoginCodeService::TooManyRequests) { @service.issue(MOBILE) }
      assert_equal 18, error.retry_after
    end
  end

  test "issue allows a new code once the resend time has passed" do
    @service.issue(MOBILE)
    wait_for_resend

    assert_nothing_raised { @service.issue(MOBILE) }
  end

  test "issue does not save a code when it refuses" do
    @service.issue(MOBILE)

    assert_no_difference -> { LoginCode.count } do
      assert_raises(LoginCodeService::TooManyRequests) { @service.issue(MOBILE) }
    end
  end

  test "issue refuses more codes than the hourly limit" do
    freeze_time do
      issue_hourly_limit
      wait_for_resend

      assert_raises(LoginCodeService::TooManyRequests) { @service.issue(MOBILE) }
    end
  end

  test "issue says how long until the oldest code in the hour stops counting" do
    freeze_time do
      first_sent_at = Time.current
      issue_hourly_limit
      wait_for_resend

      error = assert_raises(LoginCodeService::TooManyRequests) { @service.issue(MOBILE) }
      assert_equal ((first_sent_at + 1.hour) - Time.current).ceil, error.retry_after
    end
  end

  test "issue allows a code again once the oldest one is over an hour old" do
    freeze_time do
      first_sent_at = Time.current
      issue_hourly_limit
      travel_to first_sent_at + 1.hour + 1.second

      assert_nothing_raised { @service.issue(MOBILE) }
    end
  end

  test "issue does not count codes older than an hour" do
    LoginCode::MAX_PER_HOUR.times do
      @service.issue(MOBILE)
      travel 15.minutes
    end

    assert_nothing_raised { @service.issue(MOBILE) }
  end

  test "issue limits each mobile number separately" do
    @service.issue(MOBILE)

    assert_nothing_raised { @service.issue("60000002") }
  end

  test "issue applies the limits whatever spaces the mobile number has" do
    @service.issue(MOBILE)

    assert_raises(LoginCodeService::TooManyRequests) { @service.issue("5000 0001") }
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
    wait_for_resend
    with_random_number(2222) { @service.issue(MOBILE) }

    assert_not @service.verify(MOBILE, "1111")
    assert @service.verify(MOBILE, "2222")
  end

  test "verify counts a wrong attempt on the newest code only" do
    with_random_number(1111) { @service.issue(MOBILE) }
    wait_for_resend
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
    # Time travel drops fractions of a second, so wait one second past the
    # resend time to be sure the last code is old enough.
    def wait_for_resend
      travel LoginCode::RESEND_AFTER + 1.second
    end

    # Sends the hourly maximum, each just after the resend time.
    def issue_hourly_limit
      LoginCode::MAX_PER_HOUR.times do |n|
        wait_for_resend unless n.zero?
        @service.issue(MOBILE)
      end
    end

    def wrong_code(code)
      code == "0000" ? "1111" : "0000"
    end

    def with_random_number(value)
      SecureRandom.define_singleton_method(:random_number) { |*| value }
      yield
    ensure
      SecureRandom.singleton_class.remove_method(:random_number)
    end
end
