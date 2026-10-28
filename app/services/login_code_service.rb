class LoginCodeService
  class TooManyRequests < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("Too many code requests. Try again in #{retry_after} seconds.")
    end
  end

  def issue(mobile)
    ensure_code_allowed!(mobile)

    code = SecureRandom.random_number(10**LoginCode::CODE_LENGTH).to_s.rjust(LoginCode::CODE_LENGTH, "0")
    LoginCode.create!(mobile: mobile, code_digest: digest(code), expires_at: LoginCode::LIFETIME.from_now)
    code
  end

  def verify(mobile, code)
    login_code = LoginCode.where(mobile: mobile).order(created_at: :desc, id: :desc).first
    return false unless login_code

    login_code.with_lock do
      return false unless login_code.usable?

      if ActiveSupport::SecurityUtils.secure_compare(login_code.code_digest, digest(code))
        login_code.update!(consumed_at: Time.current)
        true
      else
        login_code.increment!(:attempts)
        false
      end
    end
  end

  private
    def ensure_code_allowed!(mobile)
      sent_at = LoginCode.where(mobile: mobile, created_at: 1.hour.ago..).order(created_at: :desc).pluck(:created_at)

      if sent_at.first && sent_at.first > LoginCode::RESEND_AFTER.ago
        raise TooManyRequests, seconds_until(sent_at.first + LoginCode::RESEND_AFTER)
      end

      if sent_at.size >= LoginCode::MAX_PER_HOUR
        raise TooManyRequests, seconds_until(sent_at[LoginCode::MAX_PER_HOUR - 1] + 1.hour)
      end
    end

    def seconds_until(time)
      (time - Time.current).ceil
    end

    def digest(code)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("login codes"), code.to_s)
    end
end
