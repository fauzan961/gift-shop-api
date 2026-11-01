require "test_helper"

class SessionTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a user, token digest and expiry" do
    assert build_session.valid?
  end

  test "fixtures are valid" do
    Session.find_each do |session|
      assert session.valid?, "session #{session.id}: #{session.errors.full_messages.to_sentence}"
    end
  end

  test "lasts 30 days" do
    assert_equal 30.days, Session::LIFETIME
  end

  # ---------- User ----------

  test "requires a user" do
    assert_invalid build_session(user: nil), :user, :blank
  end

  # ---------- Token digest ----------

  test "requires a token digest" do
    assert_invalid build_session(token_digest: nil), :token_digest, :blank
  end

  test "requires the token digest to be exactly 64 characters" do
    assert_invalid build_session(token_digest: "a" * 63), :token_digest, :wrong_length
    assert_invalid build_session(token_digest: "a" * 65), :token_digest, :wrong_length
  end

  # ---------- Expiry ----------

  test "requires an expiry" do
    assert_invalid build_session(expires_at: nil), :expires_at, :blank
  end

  test "is expired once the expiry has passed" do
    assert sessions(:omar_expired).expired?
    assert_not sessions(:layla_phone).expired?
  end

  test "is still valid at the exact moment of expiry, and expired a second later" do
    freeze_time do
      session = build_session(expires_at: Time.current)

      assert_not session.expired?
      travel 1.second
      assert session.expired?
    end
  end

  # ---------- Device details ----------

  test "does not require an IP address or user agent" do
    assert build_session(ip_address: nil, user_agent: nil).valid?
  end

  test "accepts a full length IPv6 address" do
    assert build_session(ip_address: "2001:0db8:85a3:0000:0000:8a2e:0370:7334").valid?
  end

  test "limits the IP address to 45 characters" do
    assert build_session(ip_address: "1" * 45).valid?
    assert_invalid build_session(ip_address: "1" * 46), :ip_address, :too_long
  end

  test "cuts a long user agent to 255 characters instead of rejecting it" do
    session = build_session(user_agent: "a" * 400)

    assert_equal 255, session.user_agent.length
    assert session.valid?
  end

  test "keeps a normal user agent unchanged" do
    user_agent = sessions(:layla_phone).user_agent

    assert_equal user_agent, build_session(user_agent: user_agent).user_agent
  end

  test "keeps a missing user agent empty" do
    assert_nil build_session(user_agent: nil).user_agent
  end

  # ---------- Scopes and associations ----------

  test "active leaves out expired sessions" do
    assert_includes Session.active, sessions(:layla_phone)
    assert_not_includes Session.active, sessions(:omar_expired)
  end

  test "active includes a session at the exact moment of expiry" do
    freeze_time do
      session = build_session(expires_at: Time.current)
      session.save!

      assert_includes Session.active, session
    end
  end

  test "a user lists all of their sessions" do
    assert_equal [ sessions(:layla_laptop), sessions(:layla_phone) ].sort_by(&:id), users(:layla).sessions.order(:id).to_a
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a duplicate token digest" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_session(token_digest: sessions(:layla_phone).token_digest).save(validate: false)
    end
  end

  test "database rejects a session without a user" do
    assert_raises(ActiveRecord::NotNullViolation) { build_session(user: nil).save(validate: false) }
  end

  test "database rejects a session for a user that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      build_session(user: nil, user_id: 0).save(validate: false)
    end
  end

  test "database rejects a session without an expiry" do
    assert_raises(ActiveRecord::NotNullViolation) { build_session(expires_at: nil).save(validate: false) }
  end

  test "deleting a user removes their sessions" do
    user = users(:layla)
    user.destroy

    assert_equal 0, Session.where(user_id: user.id).count
  end

  private
    def build_session(**attributes)
      Session.new(
        { user: users(:omar), token_digest: Digest::SHA256.hexdigest("new-token"), expires_at: 30.days.from_now }
          .merge(attributes)
      )
    end

    def assert_invalid(session, attribute, error_type)
      assert_not session.valid?, "expected #{attribute} #{error_type} error, but the session was valid"
      assert session.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{session.errors.details[attribute]}"
    end
end
