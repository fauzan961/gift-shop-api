module Admin
  class SessionsController < ActionController::Base
    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to new_admin_session_path, alert: "Too many sign-in attempts. Try again in a few minutes." }

    def new
    end

    def create
      admin_user = AdminUser.active.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)

      if admin_user
        reset_session
        session[:admin_user_id] = admin_user.id
        redirect_to admin_root_path
      else
        flash.now[:alert] = "Email or password is incorrect."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      reset_session
      redirect_to new_admin_session_path, notice: "You have been signed out."
    end
  end
end
