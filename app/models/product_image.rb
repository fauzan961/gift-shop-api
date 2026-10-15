class ProductImage < ApplicationRecord
  belongs_to :product, inverse_of: :product_images

  normalizes :image, with: ->(value) { value.strip.presence }

  validates :image, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
