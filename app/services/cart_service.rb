class CartService
  MAX_LINES = 50
  MAX_QUANTITY = 99
  DELIVERY_FEE = BigDecimal("2")
  FREE_DELIVERY_FROM = BigDecimal("25")

  def check(items)
    quantities = quantities_by_slug(items)
    products = Product.active.includes(:primary_category, :product_images).where(slug: quantities.keys).index_by(&:slug)

    lines = quantities.filter_map do |slug, quantity|
      product = products[slug]
      { product: product, quantity: quantity.clamp(1, [ product.stock, MAX_QUANTITY ].min) } if product&.in_stock?
    end

    subtotal = lines.sum(BigDecimal("0")) { |line| line[:product].price * line[:quantity] }
    delivery_fee = lines.empty? || subtotal >= FREE_DELIVERY_FROM ? BigDecimal("0") : DELIVERY_FEE

    {
      lines: lines,
      unavailable: quantities.keys - lines.map { |line| line[:product].slug },
      subtotal: subtotal,
      delivery_fee: delivery_fee,
      total: subtotal + delivery_fee
    }
  end

  private
    # Converts the cart items info sent from Angular's local-storage into a hash of quantities by slug.
    def quantities_by_slug(items)
      Array(items).first(MAX_LINES).each_with_object(Hash.new(0)) do |item, quantities|
        slug = item[:slug].to_s.strip.downcase
        quantity = Integer(item[:quantity].to_s, 10, exception: false) || 1
        quantities[slug] += quantity.clamp(1, MAX_QUANTITY) if slug.present?
      end
    end
end
