class Category < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(-[a-z0-9]+)*\z/

  normalizes :name_en, :name_ar, :tagline_en, :tagline_ar, with: ->(value) { value.strip.presence }
  normalizes :slug, with: ->(value) { value.strip.downcase }

  validates :name_en, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :name_ar, uniqueness: { allow_nil: true }, length: { maximum: 50 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 60 },
                   format: { with: SLUG_FORMAT }
  validates :tagline_en, :tagline_ar, length: { maximum: 120 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
