require "administrate/base_dashboard"

class ProductImageDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    product: Field::BelongsTo,
    image: Field::String,
    position: Field::Number,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[ id product image position ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[ id product image position created_at updated_at ].freeze

  FORM_ATTRIBUTES = %i[ product image position ].freeze

  def display_resource(product_image)
    product_image.image
  end
end
