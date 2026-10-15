class ProductCategory < ApplicationRecord
  belongs_to :product, inverse_of: :product_categories
  belongs_to :category

  validates :category_id, uniqueness: { scope: :product_id }
  validates :primary_category, inclusion: { in: [ true, false ] }
end
