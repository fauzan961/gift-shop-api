class UserSerializer
  def serialize(user)
    {
      mobile: user.mobile,
      fullName: user.full_name,
      email: user.email,
      birthday: user.birthday,
      preferences: {
        orderSms: user.order_sms,
        occasionReminders: user.occasion_reminders,
        offersEmail: user.offers_email
      }
    }
  end
end
