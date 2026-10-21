class CategorySerializer
  def serialize_collection(categories, stats = {})
    categories.map { |category| serialize(category, stats[category.id]) }
  end

  def serialize(category, stats = nil)
    {
      slug: category.slug,
      nameEn: category.name_en,
      nameAr: category.name_ar,
      emoji: category.emoji,
      taglineEn: category.tagline_en,
      taglineAr: category.tagline_ar,
      image: category.image,
      theme: category.theme,
      productCount: stats ? stats[:count] : 0,
      fromPrice: stats&.dig(:from_price)&.to_f
    }
  end
end
