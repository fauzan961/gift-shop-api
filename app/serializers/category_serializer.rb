class CategorySerializer
  def serialize_collection(categories)
    categories.map { |category| serialize(category) }
  end

  def serialize(category)
    {
      slug: category.slug,
      nameEn: category.name_en,
      nameAr: category.name_ar,
      emoji: category.emoji,
      taglineEn: category.tagline_en,
      taglineAr: category.tagline_ar,
      image: category.image,
      theme: category.theme
    }
  end
end
