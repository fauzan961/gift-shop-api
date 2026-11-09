class Address < ApplicationRecord
  ADDRESS_TYPES = %w[ Home Work Other ].freeze

  belongs_to :user

  normalizes :address, :block_area, :city, with: ->(value) { value.squish }

  validates :address_type, inclusion: { in: ADDRESS_TYPES }
  validates :address, presence: true, length: { minimum: 5, maximum: 255 }
  validates :block_area, :city, presence: true, length: { minimum: 3, maximum: 100 }
  validates :is_default, inclusion: { in: [ true, false ] }
end
