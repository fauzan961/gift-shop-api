require "administrate/base_dashboard"

class ProductDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name_en: Field::String,
    name_ar: Field::String,
    slug: Field::String,
    description_en: Field::Text,
    description_ar: Field::Text,
    price: Field::Number.with_options(decimals: 3),
    sale_price: Field::Number.with_options(decimals: 3),
    discount_percent: Field::Number,
    gender: Field::Select.with_options(collection: Product::GENDERS),
    age_group: Field::Select.with_options(collection: Product::AGE_GROUPS, include_blank: true),
    stock: Field::Number,
    rating_average: Field::Number.with_options(decimals: 1),
    reviews_count: Field::Number,
    active: Field::Boolean,
    categories: Field::HasMany,
    primary_category_id: Field::Select.with_options(collection: -> { Category.ordered.pluck(:name_en, :id) }),
    extra_categories: Field::HasMany.with_options(class_name: "Category"),
    occasions: Field::HasMany,
    product_images: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[ id name_en price sale_price discount_percent stock active ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id name_en name_ar slug description_en description_ar price sale_price discount_percent
    gender age_group stock rating_average reviews_count active categories occasions product_images created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name_en name_ar slug description_en description_ar price gender age_group stock active
    primary_category_id extra_categories occasions
  ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(active: true) },
    hidden: ->(resources) { resources.where(active: false) },
    out_of_stock: ->(resources) { resources.where(stock: 0) },
    discounted: ->(resources) { resources.where(discount_percent: 1..) }
  }.freeze

  def display_resource(product)
    product.name_en
  end
end
