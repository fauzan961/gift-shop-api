class ProductsController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 50
  MAX_FILTER_VALUES = 20
  DEFAULT_SORT = "latest"
  SORTS = {
    "latest"     => { created_at: :desc, id: :desc },
    "price-asc"  => { price: :asc, id: :desc },
    "price-desc" => { price: :desc, id: :desc },
    "rating"     => { rating_average: :desc, reviews_count: :desc, id: :desc }
  }.freeze
  GENDER_FILTERS = {
    "men"    => %w[ men unisex ],
    "women"  => %w[ women unisex ],
    "unisex" => %w[ unisex ]
  }.freeze
  AGE_GROUP_PARAMS = { "0-6" => "0-6", "6-18" => "6-18", "18-plus" => "18+" }.freeze

  def index
    scope = Product.active
    scope = filter_by_categories(scope)
    scope = filter_by_occasions(scope)
    scope = filter_by_gender(scope)
    scope = filter_by_age_groups(scope)
    total_count = scope.count

    products = scope.includes(:primary_category, :product_images)
                    .order(SORTS.fetch(sort))
                    .limit(per_page)
                    .offset((page - 1) * per_page)

    render json: {
      data: ProductSerializer.new.serialize_collection(products),
      meta: {
        page: page,
        perPage: per_page,
        totalCount: total_count,
        totalPages: (total_count.to_f / per_page).ceil,
        sort: sort,
        filters: {
          categories: category_slugs,
          occasions: occasion_slugs,
          gender: gender,
          ageGroups: age_group_values
        }
      }
    }
  end

  def show
    product = Product.active
                     .includes(:primary_category, :product_images)
                     .find_by!(slug: params[:slug].to_s.downcase)

    render json: { data: ProductSerializer.new.serialize_details(product) }
  end

  private
    def filter_by_categories(scope)
      return scope if category_slugs.empty?

      scope.where(
        id: ProductCategory.joins(:category)
                           .where(categories: { slug: category_slugs, active: true })
                           .select(:product_id)
      )
    end

    def category_slugs
      @category_slugs ||= list_param(:categories)
    end

    def filter_by_occasions(scope)
      return scope if occasion_slugs.empty?

      scope.where(
        id: ProductOccasion.joins(:occasion)
                           .where(occasions: { slug: occasion_slugs, active: true })
                           .select(:product_id)
      )
    end

    def occasion_slugs
      @occasion_slugs ||= list_param(:occasions)
    end

    def filter_by_gender(scope)
      return scope if gender.nil?

      scope.where(gender: GENDER_FILTERS.fetch(gender, []))
    end

    def gender
      @gender ||= params[:gender].to_s.strip.downcase.presence
    end

    def filter_by_age_groups(scope)
      return scope if age_group_values.empty?

      scope.where(age_group: AGE_GROUP_PARAMS.values_at(*age_group_values).compact)
    end

    def age_group_values
      @age_group_values ||= list_param(:ageGroups)
    end

    def list_param(name)
      Array(params[name]).flat_map { |value| value.to_s.split(",") }
                         .map { |value| value.strip.downcase }
                         .compact_blank
                         .uniq
                         .first(MAX_FILTER_VALUES)
    end

    def sort
      @sort ||= SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    end

    def page
      @page ||= positive_integer(params[:page]) || 1
    end

    def per_page
      @per_page ||= [ positive_integer(params[:perPage]) || DEFAULT_PER_PAGE, MAX_PER_PAGE ].min
    end

    def positive_integer(value)
      number = Integer(value.to_s, 10, exception: false)
      number if number&.positive?
    end
end
