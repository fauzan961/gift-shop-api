class ReviewSerializer
  def serialize(review)
    {
      name: review.user.full_name || "Giftie customer",
      rating: review.rating,
      comment: review.comment,
      createdAt: review.created_at
    }
  end
end
