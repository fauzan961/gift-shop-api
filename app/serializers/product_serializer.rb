class ProductSerializer
  def serialize_collection(products)
    products.map { |product| serialize(product) }
  end

  def serialize(product)
    category = product.primary_category

    {
      slug: product.slug,
      nameEn: product.name_en,
      nameAr: product.name_ar,
      category: category && { slug: category.slug, nameEn: category.name_en, nameAr: category.name_ar },
      price: product.price.to_f,
      ratingAverage: product.rating_average.to_f,
      reviewsCount: product.reviews_count,
      image: product.cover_image&.image,
      inStock: product.in_stock?
    }
  end

  def serialize_details(product)
    serialize(product).merge(
      descriptionEn: product.description_en,
      descriptionAr: product.description_ar,
      stock: product.stock,
      images: product.product_images.map(&:image),
      occasions: product.occasions.active.ordered.map do |occasion|
        { slug: occasion.slug, nameEn: occasion.name_en, nameAr: occasion.name_ar }
      end
    )
  end
end
