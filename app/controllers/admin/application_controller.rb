module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    helper_method :current_admin_user

    private
      def authenticate_admin
        redirect_to new_admin_session_path unless current_admin_user
      end

      def current_admin_user
        @current_admin_user ||= AdminUser.active.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
      end
  end
end
