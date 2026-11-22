class ReviewsController < ApplicationController
  PER_PAGE = 10

  allow_unauthenticated_access only: :index

  def index
    reviews = product.reviews.includes(:user).order(created_at: :desc, id: :desc)
                     .limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    stars = product.reviews.group(:rating).count

    render json: {
      data: reviews.map { |review| ReviewSerializer.new.serialize(review) },
      meta: {
        page: page,
        perPage: PER_PAGE,
        totalCount: product.reviews_count,
        totalPages: (product.reviews_count.to_f / PER_PAGE).ceil,
        ratingAverage: product.rating_average.to_f,
        breakdown: 5.downto(1).to_h { |star| [ star, stars.fetch(star, 0) ] }
      }
    }
  end

  def show
    review = Current.user.reviews.find_by(product: product)

    render json: {
      data: {
        review: review && ReviewSerializer.new.serialize(review),
        canReview: ReviewService.new.can_review?(Current.user, product)
      }
    }
  end

  def create
    review = ReviewService.new.create(Current.user, product, review_params)
    render json: { data: ReviewSerializer.new.serialize(review) }, status: :created
  rescue ReviewService::NotABuyer => error
    render_error(:forbidden, "not_a_buyer", error.message)
  end

  def update
    review = ReviewService.new.update(Current.user, product, review_params)
    render json: { data: ReviewSerializer.new.serialize(review) }
  end

  def destroy
    ReviewService.new.destroy(Current.user, product)
    head :no_content
  end

  private
    def product
      @product ||= Product.active.find_by!(slug: params[:product_slug].to_s.downcase)
    end

    def review_params
      params.permit(:rating, :comment)
    end

    def page
      @page ||= [ params[:page].to_i, 1 ].max
    end
end
