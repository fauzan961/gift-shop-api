class LoginCode < ApplicationRecord
  CODE_LENGTH = 4
  LIFETIME = 5.minutes
  MAX_ATTEMPTS = 5
  RESEND_AFTER = 30.seconds
  MAX_PER_HOUR = 5

  normalizes :mobile, with: ->(value) { value.gsub(/[\s-]/, "") }

  validates :mobile, format: { with: User::MOBILE_FORMAT }
  validates :code_digest, presence: true, length: { is: 64 }
  validates :expires_at, presence: true
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def usable?
    consumed_at.nil? && expires_at.future? && attempts < MAX_ATTEMPTS
  end
end
