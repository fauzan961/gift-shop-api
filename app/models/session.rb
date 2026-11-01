class Session < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :user

  normalizes :user_agent, with: ->(value) { value[0, 255] }

  validates :token_digest, presence: true, length: { is: 64 }
  validates :expires_at, presence: true
  validates :ip_address, length: { maximum: 45 }

  scope :active, -> { where(expires_at: Time.current..) }

  def expired?
    expires_at.past?
  end
end
