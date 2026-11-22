class Review < ApplicationRecord
  belongs_to :product
  belongs_to :user

  normalizes :comment, with: ->(value) { value.strip.presence }

  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :comment, length: { maximum: 1000 }
  validates :user_id, uniqueness: { scope: :product_id, message: "has already reviewed this product" }
end
