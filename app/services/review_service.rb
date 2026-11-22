class ReviewService
  class NotABuyer < StandardError; end

  def create(user, product, attributes)
    raise NotABuyer, "Only customers who received this product can review it." unless can_review?(user, product)

    product.with_lock do
      review = user.reviews.create!(attributes.merge(product: product))
      refresh_rating(product)
      review
    end
  end

  def update(user, product, attributes)
    product.with_lock do
      review = user.reviews.find_by!(product: product)
      review.update!(attributes)
      refresh_rating(product)
      review
    end
  end

  def destroy(user, product)
    product.with_lock do
      user.reviews.where(product: product).delete_all
      refresh_rating(product)
    end
  end

  def can_review?(user, product)
    user.orders.where(status: "delivered").joins(:order_items).exists?(order_items: { product_id: product.id })
  end

  private
    def refresh_rating(product)
      count, average = product.reviews.pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(rating)"))
      product.update_columns(reviews_count: count, rating_average: (average || 0).round(1))
    end
end
