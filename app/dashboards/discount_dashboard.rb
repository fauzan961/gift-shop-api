require "administrate/base_dashboard"

class DiscountDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    discount_type: Field::Select.with_options(collection: Discount::TYPES),
    value: Field::Number.with_options(decimals: 3),
    applies_to: Field::Select.with_options(collection: Discount::TARGETS),
    category: Field::BelongsTo,
    occasion: Field::BelongsTo,
    product: Field::BelongsTo,
    starts_at: Field::DateTime,
    ends_at: Field::DateTime,
    active: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[ id name discount_type value applies_to starts_at ends_at active ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id name discount_type value applies_to category occasion product starts_at ends_at active created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[ name discount_type value applies_to category occasion product starts_at ends_at active ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(active: true) },
    switched_off: ->(resources) { resources.where(active: false) }
  }.freeze

  def display_resource(discount)
    discount.name
  end
end
