class Product < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
  GENDERS = %w[ men women unisex ].freeze
  AGE_GROUPS = %w[ 0-6 6-18 18+ ].freeze
  MAX_PRICE = 10_000

  has_many :product_categories, inverse_of: :product
  has_many :categories, through: :product_categories
  has_one :primary_product_category, -> { where(primary_category: true) }, class_name: "ProductCategory"
  has_one :primary_category, through: :primary_product_category, source: :category

  has_many :product_images, -> { order(:position, :id) }, inverse_of: :product
  has_many :product_occasions, inverse_of: :product
  has_many :occasions, through: :product_occasions

  normalizes :name_en, :name_ar, :description_en, :description_ar, with: ->(value) { value.strip.presence }
  normalizes :slug, with: ->(value) { value.strip.downcase }

  validates :name_en, presence: true, length: { maximum: 100 }
  validates :name_ar, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 120 },
                   format: { with: SLUG_FORMAT }
  validates :description_en, :description_ar, length: { maximum: 2000 }
  validates :price, numericality: { greater_than: 0, less_than_or_equal_to: MAX_PRICE }
  validates :gender, inclusion: { in: GENDERS }
  validates :age_group, inclusion: { in: AGE_GROUPS }, allow_nil: true
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating_average, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :reviews_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :must_have_one_primary_category

  scope :active, -> { where(active: true) }

  def in_stock?
    stock.positive?
  end

  def cover_image
    product_images.first
  end

  def related_products(limit: 4)
    related = []

    [ shared_category_products, shared_occasion_products, Product.active ].each do |candidates|
      break if related.size >= limit

      related += candidates.where.not(id: [ id, *related.map(&:id) ])
                           .order(rating_average: :desc, reviews_count: :desc, id: :desc)
                           .limit(limit - related.size)
                           .to_a
    end

    related
  end

  private
    def shared_category_products
      Product.active.joins(:categories).where(categories: { id: category_ids, active: true }).distinct
    end

    def shared_occasion_products
      Product.active.joins(:occasions).where(occasions: { id: occasion_ids, active: true }).distinct
    end

    def must_have_one_primary_category
      links = product_categories.reject(&:marked_for_destruction?)
      return if links.count(&:primary_category) == 1

      errors.add(:product_categories, "must include exactly one primary category")
    end
end
