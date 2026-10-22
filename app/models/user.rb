class User < ApplicationRecord
  MOBILE_FORMAT = /\A[569]\d{7}\z/

  normalizes :mobile, with: ->(value) { value.gsub(/[\s-]/, "") }
  normalizes :full_name, with: ->(value) { value.squish.presence }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  validates :mobile, presence: true, uniqueness: true, format: { with: MOBILE_FORMAT }
  validates :full_name, length: { maximum: 100 }
  validates :email, uniqueness: { case_sensitive: false }, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :order_sms, :occasion_reminders, :offers_email, :active, inclusion: { in: [ true, false ] }
  validate :birthday_cannot_be_in_the_future

  scope :active, -> { where(active: true) }

  private
    def birthday_cannot_be_in_the_future
      errors.add(:birthday, "can't be in the future") if birthday&.future?
    end
end
