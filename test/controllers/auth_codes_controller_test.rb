require "test_helper"

class AuthCodesControllerTest < ActionDispatch::IntegrationTest
  MOBILE = "50000001"

  setup do
    AuthCodesController.cache_store.clear
  end

  # ---------- Sending a code ----------

  test "create sends a code and says when it can be resent and when it expires" do
    post auth_code_url, params: { mobile: MOBILE }, as: :json

    assert_response :accepted
    assert_equal({ "data" => { "resendAfter" => 30, "expiresIn" => 300 } }, response.parsed_body)
  end

  test "create saves a code for the mobile number" do
    assert_difference -> { LoginCode.where(mobile: MOBILE).count }, 1 do
      post auth_code_url, params: { mobile: MOBILE }, as: :json
    end
  end

  test "create texts a code that can then be verified" do
    log = capture_log { post auth_code_url, params: { mobile: MOBILE }, as: :json }
    code = log[/Your verification code is (\d{#{LoginCode::CODE_LENGTH}})/, 1]

    assert_includes log, "to +965#{MOBILE}"
    assert code, "expected the code in the text message"
    assert LoginCodeService.new.verify(MOBILE, code)
  end

  test "create never returns the code in the response" do
    log = capture_log { post auth_code_url, params: { mobile: MOBILE }, as: :json }
    code = log[/Your verification code is (\d+)/, 1]

    assert_not_includes response.body, code
  end

  test "create accepts a mobile number with spaces or dashes" do
    post auth_code_url, params: { mobile: " 5000-0001 " }, as: :json

    assert_response :accepted
    assert LoginCode.exists?(mobile: MOBILE)
  end

  test "create gives the same response for registered and new numbers" do
    post auth_code_url, params: { mobile: users(:layla).mobile }, as: :json
    registered = response.parsed_body

    post auth_code_url, params: { mobile: "69999999" }, as: :json

    assert_response :accepted
    assert_equal registered, response.parsed_body
  end

  test "create does not create a user" do
    assert_no_difference -> { User.count } do
      post auth_code_url, params: { mobile: "69999999" }, as: :json
    end
  end

  # ---------- Invalid input ----------

  test "create rejects a badly formatted mobile number" do
    post auth_code_url, params: { mobile: "40000000" }, as: :json

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal [ "is invalid" ], response.parsed_body.dig("error", "details", "mobile")
  end

  test "create rejects a missing mobile number" do
    post auth_code_url, params: {}, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body.dig("error", "details").keys, "mobile"
  end

  test "create does not save a code for an invalid mobile number" do
    assert_no_difference -> { LoginCode.count } do
      post auth_code_url, params: { mobile: "40000000" }, as: :json
    end
  end

  # ---------- Per-number limits ----------

  test "create refuses a new code within the resend time" do
    freeze_time do
      post auth_code_url, params: { mobile: MOBILE }, as: :json
      travel 12.seconds
      post auth_code_url, params: { mobile: MOBILE }, as: :json

      assert_response :too_many_requests
      assert_equal "too_many_requests", response.parsed_body.dig("error", "code")
      assert_equal 18, response.parsed_body.dig("error", "retryAfter")
      assert_equal "18", response.headers["Retry-After"]
    end
  end

  test "create refuses more codes than the hourly limit for a number" do
    freeze_time do
      LoginCode::MAX_PER_HOUR.times do
        post auth_code_url, params: { mobile: MOBILE }, as: :json
        travel LoginCode::RESEND_AFTER + 1.second
      end

      post auth_code_url, params: { mobile: MOBILE }, as: :json

      assert_response :too_many_requests
      assert_operator response.parsed_body.dig("error", "retryAfter"), :>, LoginCode::RESEND_AFTER
    end
  end

  # ---------- Per-IP limit ----------

  test "create refuses requests past the limit for one IP address" do
    AuthCodesController::IP_LIMIT.times do |n|
      post auth_code_url, params: { mobile: "5#{n.to_s.rjust(7, "0")}" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
      assert_response :accepted
    end

    post auth_code_url, params: { mobile: "59999999" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }

    assert_response :too_many_requests
    assert_equal AuthCodesController::IP_LIMIT_WINDOW.to_i, response.parsed_body.dig("error", "retryAfter")
    assert_equal AuthCodesController::IP_LIMIT_WINDOW.to_i.to_s, response.headers["Retry-After"]
  end

  test "create does not send a code when the IP limit is reached" do
    AuthCodesController::IP_LIMIT.times do |n|
      post auth_code_url, params: { mobile: "5#{n.to_s.rjust(7, "0")}" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
    end

    assert_no_difference -> { LoginCode.count } do
      post auth_code_url, params: { mobile: "59999999" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
    end
  end

  test "create limits each IP address separately" do
    AuthCodesController::IP_LIMIT.times do |n|
      post auth_code_url, params: { mobile: "5#{n.to_s.rjust(7, "0")}" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
    end

    post auth_code_url, params: { mobile: "59999999" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.2" }

    assert_response :accepted
  end

  private
    def capture_log
      original = Rails.logger
      output = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(output)
      yield
      output.string
    ensure
      Rails.logger = original
    end
end
