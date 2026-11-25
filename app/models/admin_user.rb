class AdminUser < ApplicationRecord
  MIN_PASSWORD_LENGTH = 8

  has_secure_password

  normalizes :name, with: ->(value) { value.squish }
  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, uniqueness: true, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
end
