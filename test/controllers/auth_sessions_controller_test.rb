require "test_helper"

class AuthSessionsControllerTest < ActionDispatch::IntegrationTest
  NEW_MOBILE = "69999999"

  setup do
    AuthSessionsController.cache_store.clear
    @codes = LoginCodeService.new
  end

  # ---------- Signing in ----------

  test "verify signs in an existing user and returns a working token" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json

    assert_response :created
    token = response.parsed_body.dig("data", "token")
    assert_equal users(:layla), SessionService.new.find(token).user
  end

  test "verify returns the user's profile" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json

    assert_equal(
      {
        "mobile" => "50000001",
        "fullName" => "Layla Al-Sabah",
        "email" => "layla@mail.com",
        "birthday" => "1995-03-21",
        "preferences" => { "orderSms" => true, "occasionReminders" => true, "offersEmail" => true }
      },
      response.parsed_body.dig("data", "user")
    )
    assert_equal false, response.parsed_body.dig("data", "newUser")
  end

  test "verify does not create a user for an existing number" do
    code = @codes.issue(users(:layla).mobile)

    assert_no_difference -> { User.count } do
      post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json
    end
  end

  test "verify creates the account on a first sign-in" do
    code = @codes.issue(NEW_MOBILE)

    assert_difference -> { User.count }, 1 do
      post auth_verify_url, params: { mobile: NEW_MOBILE, code: code }, as: :json
    end

    assert_response :created
    assert_equal true, response.parsed_body.dig("data", "newUser")
    assert_equal NEW_MOBILE, response.parsed_body.dig("data", "user", "mobile")
    assert_nil response.parsed_body.dig("data", "user", "fullName")
  end

  test "verify saves the device details on the session" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url,
         params: { mobile: users(:layla).mobile, code: code }, as: :json,
         headers: { "User-Agent" => "Chrome on iPhone" }, env: { "REMOTE_ADDR" => "10.0.0.7" }

    session = SessionService.new.find(response.parsed_body.dig("data", "token"))
    assert_equal "10.0.0.7", session.ip_address
    assert_equal "Chrome on iPhone", session.user_agent
  end

  test "verify accepts a mobile number with spaces or dashes" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: " 5000-0001 ", code: code }, as: :json

    assert_response :created
  end

  test "verify never returns the code or anything stored about it" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json

    assert_not_includes response.body, LoginCode.last.code_digest
    assert_equal %w[ token newUser user ], response.parsed_body["data"].keys
  end

  # ---------- Wrong codes ----------

  test "verify rejects a wrong code" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: wrong_code(code) }, as: :json

    assert_response :unauthorized
    assert_equal(
      { "error" => { "code" => "invalid_code", "message" => "The code is incorrect or has expired." } },
      response.parsed_body
    )
  end

  test "verify counts a wrong code as an attempt" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: wrong_code(code) }, as: :json

    assert_equal 1, LoginCode.last.attempts
  end

  test "verify does not sign in or create an account for a wrong code" do
    code = @codes.issue(NEW_MOBILE)

    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      post auth_verify_url, params: { mobile: NEW_MOBILE, code: wrong_code(code) }, as: :json
    end
  end

  test "verify rejects a code that was already used" do
    code = @codes.issue(users(:layla).mobile)
    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json

    assert_response :unauthorized
  end

  test "verify rejects an expired code" do
    code = @codes.issue(users(:layla).mobile)

    travel LoginCode::LIFETIME + 1.second do
      post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json
    end

    assert_response :unauthorized
  end

  test "verify rejects a code sent to another number" do
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:omar).mobile, code: code }, as: :json

    assert_response :unauthorized
  end

  test "verify rejects a request when no code was ever sent" do
    post auth_verify_url, params: { mobile: NEW_MOBILE, code: "1234" }, as: :json

    assert_response :unauthorized
  end

  test "verify rejects missing details" do
    post auth_verify_url, params: {}, as: :json

    assert_response :unauthorized
    assert_equal "invalid_code", response.parsed_body.dig("error", "code")
  end

  # ---------- Blocked users ----------

  test "verify refuses a blocked user" do
    code = @codes.issue(users(:blocked).mobile)

    assert_no_difference -> { Session.count } do
      post auth_verify_url, params: { mobile: users(:blocked).mobile, code: code }, as: :json
    end

    assert_response :forbidden
    assert_equal "account_blocked", response.parsed_body.dig("error", "code")
  end

  # ---------- Per-IP limit ----------

  test "verify refuses attempts past the limit for one IP address" do
    AuthSessionsController::IP_LIMIT.times do
      post auth_verify_url, params: { mobile: NEW_MOBILE, code: "0000" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
    end

    post auth_verify_url, params: { mobile: NEW_MOBILE, code: "0000" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }

    assert_response :too_many_requests
    assert_equal "too_many_requests", response.parsed_body.dig("error", "code")
    assert_equal AuthSessionsController::IP_LIMIT_WINDOW.to_i.to_s, response.headers["Retry-After"]
  end

  test "verify limits each IP address separately" do
    AuthSessionsController::IP_LIMIT.times do
      post auth_verify_url, params: { mobile: NEW_MOBILE, code: "0000" }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.1" }
    end
    code = @codes.issue(users(:layla).mobile)

    post auth_verify_url, params: { mobile: users(:layla).mobile, code: code }, as: :json, env: { "REMOTE_ADDR" => "10.0.0.2" }

    assert_response :created
  end

  private
    def wrong_code(code)
      code == "0000" ? "1111" : "0000"
    end
end
