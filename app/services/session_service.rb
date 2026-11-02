class SessionService
  REFRESH_AFTER = 1.hour

  def start(user, ip_address: nil, user_agent: nil)
    token = SecureRandom.urlsafe_base64(32)
    user.sessions.create!(
      token_digest: digest(token),
      expires_at: Session::LIFETIME.from_now,
      last_used_at: Time.current,
      ip_address: ip_address,
      user_agent: user_agent
    )
    token
  end

  def find(token)
    return if token.blank?

    session = Session.active.includes(:user).find_by(token_digest: digest(token))
    return unless session&.user&.active?

    refresh(session)
    session
  end

  def finish(token)
    Session.where(token_digest: digest(token)).delete_all if token.present?
  end

  private
    def refresh(session)
      return if session.last_used_at&.after?(REFRESH_AFTER.ago)

      session.update_columns(last_used_at: Time.current, expires_at: Session::LIFETIME.from_now)
    end

    def digest(token)
      Digest::SHA256.hexdigest(token)
    end
end
