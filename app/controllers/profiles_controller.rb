class ProfilesController < ApplicationController
  def show
    render json: { data: UserSerializer.new.serialize(Current.user) }
  end

  def update
    Current.user.update!(profile_params)
    render json: { data: UserSerializer.new.serialize(Current.user) }
  end

  private
    def profile_params
      params.permit(:full_name, :email, :birthday, :order_sms, :occasion_reminders, :offers_email)
    end
end
