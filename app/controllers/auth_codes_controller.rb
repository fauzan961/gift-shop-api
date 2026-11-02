class AuthCodesController < ApplicationController
  IP_LIMIT = 10
  IP_LIMIT_WINDOW = 1.hour

  rate_limit to: IP_LIMIT, within: IP_LIMIT_WINDOW,
             with: -> { render_too_many_requests(IP_LIMIT_WINDOW.to_i, "Too many code requests from this network.") }

  def create
    mobile = LoginCode.normalize_value_for(:mobile, params[:mobile].to_s)
    code = LoginCodeService.new.issue(mobile)
    TextMessageService.new.deliver(mobile, "Your verification code is #{code}. It expires in #{LoginCode::LIFETIME.in_minutes.to_i} minutes.")

    render json: { data: { resendAfter: LoginCode::RESEND_AFTER.to_i, expiresIn: LoginCode::LIFETIME.to_i } },
           status: :accepted
  rescue LoginCodeService::TooManyRequests => error
    render_too_many_requests(error.retry_after, error.message)
  end
end
