class LoginCodeService
  def issue(mobile)
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
    def digest(code)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("login codes"), code.to_s)
    end
end
