class ProductOccasion < ApplicationRecord
  belongs_to :product, inverse_of: :product_occasions
  belongs_to :occasion

  validates :occasion_id, uniqueness: { scope: :product_id }
end
