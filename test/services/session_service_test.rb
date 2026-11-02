require "test_helper"

class SessionServiceTest < ActiveSupport::TestCase
  setup do
    @service = SessionService.new
  end

  # ---------- start ----------

  test "start returns a long random token" do
    token = @service.start(users(:omar))

    assert_match(/\A[A-Za-z0-9_-]{43}\z/, token)
  end

  test "start gives every session a different token" do
    assert_not_equal @service.start(users(:omar)), @service.start(users(:omar))
  end

  test "start saves a session for the user" do
    assert_difference -> { users(:omar).sessions.count }, 1 do
      @service.start(users(:omar))
    end
  end

  test "start stores only a hash of the token, never the token itself" do
    token = @service.start(users(:omar))
    session = Session.order(:id).last

    assert_equal Digest::SHA256.hexdigest(token), session.token_digest
    assert_not_includes session.attributes.values.map(&:to_s), token
  end

  test "start sets the expiry 30 days ahead and marks the session as just used" do
    freeze_time do
      @service.start(users(:omar))
      session = Session.order(:id).last

      assert_equal Session::LIFETIME.from_now, session.expires_at
      assert_equal Time.current, session.last_used_at
    end
  end

  test "start stores the device details" do
    @service.start(users(:omar), ip_address: "10.0.0.1", user_agent: "Chrome on iPhone")
    session = Session.order(:id).last

    assert_equal "10.0.0.1", session.ip_address
    assert_equal "Chrome on iPhone", session.user_agent
  end

  test "start cuts a long user agent instead of failing" do
    assert_nothing_raised { @service.start(users(:omar), user_agent: "a" * 400) }
    assert_equal 255, Session.order(:id).last.user_agent.length
  end

  # ---------- find ----------

  test "find returns the session for a token" do
    assert_equal sessions(:layla_phone), @service.find("layla-phone-token")
  end

  test "find returns the session with its user" do
    assert_equal users(:layla), @service.find("layla-phone-token").user
  end

  test "find works with a token from start" do
    token = @service.start(users(:omar))

    assert_equal users(:omar), @service.find(token).user
  end

  test "find returns nil for an unknown token" do
    assert_nil @service.find("not-a-real-token")
  end

  test "find returns nil for a blank token" do
    assert_nil @service.find(nil)
    assert_nil @service.find("")
  end

  test "find returns nil for an expired session" do
    assert_nil @service.find("omar-expired-token")
  end

  test "find returns nil for a blocked user" do
    token = @service.start(users(:blocked))

    assert_nil @service.find(token)
  end

  test "find returns nil once a user is blocked" do
    token = @service.start(users(:omar))
    users(:omar).update!(active: false)

    assert_nil @service.find(token)
  end

  # ---------- Extending the expiry ----------

  test "find extends a session that has not been used for over an hour" do
    freeze_time do
      @service.find("layla-phone-token")
      session = sessions(:layla_phone).reload

      assert_equal Time.current, session.last_used_at
      assert_equal Session::LIFETIME.from_now, session.expires_at
    end
  end

  test "find does not extend a session used within the hour" do
    token = @service.start(users(:omar))
    session = Session.order(:id).last
    first_expiry = session.expires_at

    travel 30.minutes do
      @service.find(token)

      assert_equal first_expiry, session.reload.expires_at
    end
  end

  test "find extends a session again once the hour has passed" do
    token = @service.start(users(:omar))
    session = Session.order(:id).last
    first_expiry = session.expires_at

    travel SessionService::REFRESH_AFTER + 1.minute do
      @service.find(token)

      assert_operator session.reload.expires_at, :>, first_expiry
    end
  end

  # ---------- finish ----------

  test "finish deletes the session for a token" do
    session_id = sessions(:layla_phone).id
    @service.finish("layla-phone-token")

    assert_not Session.exists?(session_id)
    assert_nil @service.find("layla-phone-token")
  end

  test "finish leaves the user's other sessions alone" do
    @service.finish("layla-phone-token")

    assert Session.exists?(sessions(:layla_laptop).id)
  end

  test "finish does nothing for an unknown or blank token" do
    assert_no_difference -> { Session.count } do
      @service.finish("not-a-real-token")
      @service.finish(nil)
      @service.finish("")
    end
  end
end
