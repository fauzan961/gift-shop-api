module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def require_authentication
      resume_session || render_unauthenticated
    end

    def resume_session
      Current.session ||= SessionService.new.find(bearer_token)
    end

    def bearer_token
      request.authorization.to_s[/\ABearer (\S+)\z/i, 1]
    end

    def render_unauthenticated
      response.headers["WWW-Authenticate"] = "Bearer"
      render_error(:unauthorized, "unauthenticated", "Please sign in to continue.")
    end
end
