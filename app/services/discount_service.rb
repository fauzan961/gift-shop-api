class DiscountService
  def refresh
    running = Discount.where(active: true, starts_at: ..Time.current).where("ends_at IS NULL OR ends_at > ?", Time.current).to_a

    Product.includes(:product_categories, :product_occasions).find_each do |product|
      sale_price = best_price(product, running)
      discount_percent = ((product.price - sale_price) / product.price * 100).round
      next if product.sale_price == sale_price && product.discount_percent == discount_percent

      product.update_columns(sale_price: sale_price, discount_percent: discount_percent)
    end
  end

  private
    def best_price(product, discounts)
      prices = discounts.filter_map do |discount|
        next unless applies?(discount, product)

        price = discounted(product.price, discount)
        price if price.positive?
      end
      [ product.price, *prices ].min
    end

    def applies?(discount, product)
      case discount.applies_to
      when "all" then true
      when "category" then product.product_categories.any? { |link| link.category_id == discount.category_id }
      when "occasion" then product.product_occasions.any? { |link| link.occasion_id == discount.occasion_id }
      when "product" then discount.product_id == product.id
      end
    end

    def discounted(price, discount)
      if discount.discount_type == "percentage"
        (price * (100 - discount.value) / 100).round(3)
      else
        price - discount.value
      end
    end
end
