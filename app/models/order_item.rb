class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product, optional: true

  validates :product_name_en, presence: true, length: { maximum: 100 }
  validates :product_name_ar, length: { maximum: 100 }
  validates :unit_price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, in: 1..99 }
  validates :line_total, numericality: true
  validate :line_total_must_add_up

  private
    def line_total_must_add_up
      return if unit_price.nil? || quantity.nil?

      errors.add(:line_total, "must equal the unit price times the quantity") unless line_total == unit_price * quantity
    end
end
