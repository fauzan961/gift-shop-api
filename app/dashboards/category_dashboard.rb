require "administrate/base_dashboard"

class CategoryDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name_en: Field::String,
    name_ar: Field::String,
    slug: Field::String,
    emoji: Field::String,
    tagline_en: Field::String,
    tagline_ar: Field::String,
    image: Field::String,
    theme: Field::String,
    position: Field::Number,
    active: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[ id name_en name_ar slug position active ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id name_en name_ar slug emoji tagline_en tagline_ar image theme position active created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[ name_en name_ar slug emoji tagline_en tagline_ar image theme position active ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(active: true) },
    hidden: ->(resources) { resources.where(active: false) }
  }.freeze

  def display_resource(category)
    category.name_en
  end
end
