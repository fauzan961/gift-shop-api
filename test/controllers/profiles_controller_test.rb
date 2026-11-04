require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  LAYLA_PROFILE = {
    "mobile" => "50000001",
    "fullName" => "Layla Al-Sabah",
    "email" => "layla@mail.com",
    "birthday" => "1995-03-21",
    "preferences" => { "orderSms" => true, "occasionReminders" => true, "offersEmail" => true }
  }

  # ---------- Viewing ----------

  test "show returns the signed-in user's profile" do
    get profile_url, headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal({ "data" => LAYLA_PROFILE }, response.parsed_body)
  end

  test "show returns the profile of whoever the token belongs to" do
    get profile_url, headers: bearer(SessionService.new.start(users(:omar)))

    assert_equal "60000002", response.parsed_body.dig("data", "mobile")
    assert_nil response.parsed_body.dig("data", "fullName")
  end

  test "show without a valid token is refused" do
    [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
      get profile_url, headers: headers

      assert_response :unauthorized
      assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
    end
  end

  # ---------- Updating ----------

  test "update saves every field and returns the new profile" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: {
      full_name: "Layla Al-Ahmad", email: "layla.ahmad@mail.com", birthday: "1996-04-22",
      order_sms: false, occasion_reminders: false, offers_email: false
    }

    assert_response :success
    assert_equal(
      {
        "mobile" => "50000001",
        "fullName" => "Layla Al-Ahmad",
        "email" => "layla.ahmad@mail.com",
        "birthday" => "1996-04-22",
        "preferences" => { "orderSms" => false, "occasionReminders" => false, "offersEmail" => false }
      },
      response.parsed_body["data"]
    )
  end

  test "update changes only the fields that were sent" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { offers_email: false }

    assert_response :success
    assert_equal LAYLA_PROFILE.deep_merge("preferences" => { "offersEmail" => false }), response.parsed_body["data"]
  end

  test "update with nothing to change returns the profile as it is" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: {}

    assert_response :success
    assert_equal LAYLA_PROFILE, response.parsed_body["data"]
  end

  test "update clears the name, email and birthday when sent as null or blank" do
    [ nil, "" ].each do |blank|
      patch profile_url, headers: bearer("layla-phone-token"), as: :json,
            params: { full_name: blank, email: blank, birthday: blank }

      assert_response :success, "sent #{blank.inspect}"
      user = users(:layla).reload
      assert_nil user.full_name
      assert_nil user.email
      assert_nil user.birthday
    end
  end

  test "update tidies the name and email the same way the model does" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json,
          params: { full_name: "  Layla   Al-Ahmad ", email: " Layla@Mail.COM " }

    assert_equal "Layla Al-Ahmad", response.parsed_body.dig("data", "fullName")
    assert_equal "layla@mail.com", response.parsed_body.dig("data", "email")
  end

  test "update ignores the mobile number and unknown fields" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json,
          params: { mobile: "69999999", active: false, full_name: "Layla Al-Ahmad" }

    assert_response :success
    user = users(:layla).reload
    assert_equal "50000001", user.mobile
    assert user.active
    assert_equal "Layla Al-Ahmad", user.full_name
  end

  test "update changes only the signed-in user" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { full_name: "Layla Al-Ahmad" }

    assert_nil users(:omar).reload.full_name
    assert_equal "Blocked User", users(:blocked).reload.full_name
  end

  test "update without a valid token is refused and saves nothing" do
    [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
      patch profile_url, headers: headers, as: :json, params: { full_name: "Someone Else" }

      assert_response :unauthorized
    end

    assert_equal "Layla Al-Sabah", users(:layla).reload.full_name
  end

  # ---------- Validation errors ----------

  test "update rejects a badly formatted email" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { email: "layla@" }

    assert_validation_failed "email", "is invalid"
  end

  test "update rejects an email already used by another user" do
    patch profile_url, headers: bearer(SessionService.new.start(users(:omar))), as: :json,
          params: { email: "LAYLA@mail.com" }

    assert_validation_failed "email", "has already been taken"
    assert_nil users(:omar).reload.email
  end

  test "update lets a user keep their own email" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { email: "LAYLA@mail.com" }

    assert_response :success
  end

  test "update rejects a birthday that is not a real date" do
    [ "not-a-date", "2024-02-30" ].each do |birthday|
      patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { birthday: birthday }

      assert_validation_failed "birthday", "is not a valid date"
    end
  end

  test "update rejects a birthday in the future" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { birthday: Date.tomorrow.to_s }

    assert_validation_failed "birthday", "can't be in the future"
  end

  test "update rejects a name over 100 characters" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json, params: { full_name: "a" * 101 }

    assert_validation_failed "fullName", "is too long (maximum is 100 characters)"
  end

  test "update saves nothing when one field is invalid" do
    patch profile_url, headers: bearer("layla-phone-token"), as: :json,
          params: { full_name: "Layla Al-Ahmad", email: "layla@" }

    assert_response :unprocessable_content
    assert_equal "Layla Al-Sabah", users(:layla).reload.full_name
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_validation_failed(key, message)
      assert_response :unprocessable_content
      assert_equal "validation_failed", response.parsed_body.dig("error", "code")
      assert_includes response.parsed_body.dig("error", "details", key), message
    end
end
