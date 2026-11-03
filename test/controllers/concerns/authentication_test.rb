require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  class PrivateController < ApplicationController
    def show
      render json: { data: { mobile: Current.user.mobile, sessionId: Current.session.id } }
    end
  end

  class OptionalController < ApplicationController
    allow_unauthenticated_access

    def show
      resume_session
      render json: { data: { signedIn: Current.user.present?, mobile: Current.user&.mobile } }
    end
  end

  with_routing do |routes|
    routes.draw do
      get "test/private", to: "authentication_test/private#show"
      get "test/optional", to: "authentication_test/optional#show"
    end
  end

  # ---------- Turned away ----------

  test "a request without a token is turned away" do
    get "/test/private"

    assert_unauthenticated
  end

  test "a request with a badly formed header is turned away" do
    [ "Token layla-phone-token", "Bearer", "Bearer ", "Bearer two words", "layla-phone-token" ].each do |header|
      get "/test/private", headers: { "Authorization" => header }

      assert_unauthenticated "Authorization: #{header.inspect}"
    end
  end

  test "a request with an unknown token is turned away" do
    get "/test/private", headers: bearer("not-a-real-token")

    assert_unauthenticated
  end

  test "a request with an expired session is turned away" do
    get "/test/private", headers: bearer("omar-expired-token")

    assert_unauthenticated
  end

  test "a request from a blocked user is turned away" do
    token = SessionService.new.start(users(:blocked))

    get "/test/private", headers: bearer(token)

    assert_unauthenticated
  end

  test "a request is turned away after signing out" do
    SessionService.new.finish("layla-phone-token")

    get "/test/private", headers: bearer("layla-phone-token")

    assert_unauthenticated
  end

  # ---------- Let through ----------

  test "a request with a valid token reaches the action as that user" do
    get "/test/private", headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal(
      { "mobile" => users(:layla).mobile, "sessionId" => sessions(:layla_phone).id },
      response.parsed_body["data"]
    )
  end

  test "the word Bearer is accepted in any letter case" do
    get "/test/private", headers: { "Authorization" => "bearer layla-phone-token" }

    assert_response :success
  end

  test "each request is recognised as its own user" do
    omar_token = SessionService.new.start(users(:omar))

    get "/test/private", headers: bearer("layla-phone-token")
    assert_equal users(:layla).mobile, response.parsed_body.dig("data", "mobile")

    get "/test/private", headers: bearer(omar_token)
    assert_equal users(:omar).mobile, response.parsed_body.dig("data", "mobile")

    get "/test/private"
    assert_unauthenticated "a request without a token must not reuse the previous user"
  end

  test "a request with a valid token extends the session" do
    freeze_time do
      get "/test/private", headers: bearer("layla-phone-token")

      assert_equal Time.current, sessions(:layla_phone).reload.last_used_at
    end
  end

  # ---------- Optional sign-in ----------

  test "an optional action works without a token" do
    get "/test/optional"

    assert_response :success
    assert_equal({ "signedIn" => false, "mobile" => nil }, response.parsed_body["data"])
  end

  test "an optional action recognises a signed-in user" do
    get "/test/optional", headers: bearer("layla-phone-token")

    assert_equal({ "signedIn" => true, "mobile" => users(:layla).mobile }, response.parsed_body["data"])
  end

  test "an optional action treats an invalid token as signed out, not as an error" do
    get "/test/optional", headers: bearer("not-a-real-token")

    assert_response :success
    assert_equal false, response.parsed_body.dig("data", "signedIn")
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_unauthenticated(context = nil)
      assert_response :unauthorized, context
      assert_equal "Bearer", response.headers["WWW-Authenticate"], context
      assert_equal(
        { "error" => { "code" => "unauthenticated", "message" => "Please sign in to continue." } },
        response.parsed_body,
        context
      )
    end
end
