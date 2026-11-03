class AuthSessionsController < ApplicationController
  IP_LIMIT = 20
  IP_LIMIT_WINDOW = 1.hour

  allow_unauthenticated_access only: :create

  rate_limit to: IP_LIMIT, within: IP_LIMIT_WINDOW, only: :create,
             with: -> { render_too_many_requests(IP_LIMIT_WINDOW.to_i, "Too many sign-in attempts from this network.") }

  def create
    mobile = LoginCode.normalize_value_for(:mobile, params[:mobile].to_s)

    unless LoginCodeService.new.verify(mobile, params[:code].to_s)
      return render_error(:unauthorized, "invalid_code", "The code is incorrect or has expired.")
    end

    user = User.find_or_create_by!(mobile: mobile)
    return render_error(:forbidden, "account_blocked", "This account has been blocked.") unless user.active?

    token = SessionService.new.start(user, ip_address: request.remote_ip, user_agent: request.user_agent)

    render json: {
      data: { token: token, newUser: user.previously_new_record?, user: UserSerializer.new.serialize(user) }
    }, status: :created
  end

  def destroy
    Current.session.destroy
    head :no_content
  end
end
