class Discount < ApplicationRecord
  TYPES = %w[ percentage amount ].freeze
  TARGETS = %w[ all category occasion product ].freeze

  belongs_to :category, optional: true
  belongs_to :occasion, optional: true
  belongs_to :product, optional: true

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :discount_type, inclusion: { in: TYPES }
  validates :applies_to, inclusion: { in: TARGETS }
  validates :value, numericality: { greater_than: 0 }
  validates :value, numericality: { in: 1..100 }, if: -> { discount_type == "percentage" }
  validates :starts_at, presence: true
  validates :ends_at, comparison: { greater_than: :starts_at, message: "must be after the start" }, allow_nil: true, if: :starts_at?
  validates :active, inclusion: { in: [ true, false ] }
  validate :target_must_match

  private
    def target_must_match
      %w[ category occasion product ].each do |target|
        if target == applies_to
          errors.add(target, :blank) if public_send("#{target}_id").nil?
        elsif public_send("#{target}_id")
          errors.add(target, "must be empty when the discount applies to #{applies_to}")
        end
      end
    end
end
