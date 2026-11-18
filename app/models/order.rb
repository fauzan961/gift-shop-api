class Order < ApplicationRecord
  STATUSES = %w[ pending_payment preparing on_the_way delivered cancelled expired].freeze
  DELIVERY_SLOTS = %w[ 09-12 12-15 15-18 18-21 ].freeze
  PAYMENT_METHODS = %w[ mpgs knet apple_pay ].freeze

  belongs_to :user
  has_many :order_items

  normalizes :recipient_name, :address, :block_area, :city, with: ->(value) { value.squish }
  normalizes :gift_message, with: ->(value) { value.strip.presence }

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :recipient_name, presence: true, length: { maximum: 100 }
  validates :address, presence: true, length: { minimum: 5, maximum: 255 }
  validates :block_area, :city, presence: true, length: { minimum: 3, maximum: 100 }
  validates :delivery_date, presence: true
  validates :delivery_slot, inclusion: { in: DELIVERY_SLOTS }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :gift_message, length: { maximum: 200 }
  validates :subtotal, numericality: { greater_than: 0 }
  validates :delivery_fee, numericality: { greater_than_or_equal_to: 0 }
  validates :total, numericality: true
  validate :total_must_add_up

  private
    def total_must_add_up
      return if subtotal.nil? || delivery_fee.nil?

      errors.add(:total, "must equal the subtotal plus the delivery fee") unless total == subtotal + delivery_fee
    end
end
