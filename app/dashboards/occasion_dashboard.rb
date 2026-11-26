require "administrate/base_dashboard"

class OccasionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name_en: Field::String,
    name_ar: Field::String,
    slug: Field::String,
    emoji: Field::String,
    tagline_en: Field::String,
    tagline_ar: Field::String,
    image: Field::String,
    occurs_on: Field::Date,
    featured: Field::Boolean,
    position: Field::Number,
    active: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[ id name_en name_ar slug occurs_on featured position active ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id name_en name_ar slug emoji tagline_en tagline_ar image occurs_on featured position active created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[ name_en name_ar slug emoji tagline_en tagline_ar image occurs_on featured position active ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(active: true) },
    hidden: ->(resources) { resources.where(active: false) },
    featured: ->(resources) { resources.where(featured: true) }
  }.freeze

  def display_resource(occasion)
    occasion.name_en
  end
end
