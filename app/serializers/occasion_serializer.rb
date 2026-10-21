class OccasionSerializer
  def serialize_collection(occasions, product_counts = {})
    occasions.map { |occasion| serialize(occasion, product_counts[occasion.id]) }
  end

  def serialize(occasion, product_count = nil)
    {
      slug: occasion.slug,
      nameEn: occasion.name_en,
      nameAr: occasion.name_ar,
      emoji: occasion.emoji,
      taglineEn: occasion.tagline_en,
      taglineAr: occasion.tagline_ar,
      image: occasion.image,
      occursOn: occasion.upcoming_date,
      featured: occasion.featured,
      productCount: product_count || 0
    }
  end
end
