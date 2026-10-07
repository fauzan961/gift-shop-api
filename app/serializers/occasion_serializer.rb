class OccasionSerializer
  def serialize_collection(occasions)
    occasions.map { |occasion| serialize(occasion) }
  end

  def serialize(occasion)
    {
      slug: occasion.slug,
      nameEn: occasion.name_en,
      nameAr: occasion.name_ar,
      emoji: occasion.emoji,
      taglineEn: occasion.tagline_en,
      taglineAr: occasion.tagline_ar,
      image: occasion.image,
      occursOn: occasion.upcoming_date,
      featured: occasion.featured
    }
  end
end
