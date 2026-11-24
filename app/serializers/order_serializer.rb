class OrderSerializer
  def serialize(order)
    {
      number: order.number,
      status: order.status,
      placedAt: order.created_at,
      recipientName: order.recipient_name,
      address: order.address,
      blockArea: order.block_area,
      city: order.city,
      deliveryDate: order.delivery_date,
      deliverySlot: order.delivery_slot,
      giftMessage: order.gift_message,
      paymentMethod: order.payment_method,
      subtotal: order.subtotal.to_f,
      deliveryFee: order.delivery_fee.to_f,
      total: order.total.to_f,
      items: order.order_items.map do |item|
        category = item.product&.primary_category

        {
          productSlug: item.product&.slug,
          nameEn: item.product_name_en,
          nameAr: item.product_name_ar,
          category: category && { slug: category.slug, nameEn: category.name_en, nameAr: category.name_ar },
          image: item.product&.cover_image&.image,
          unitPrice: item.unit_price.to_f,
          originalPrice: item.original_price.to_f,
          discountAmount: item.discount_amount.to_f,
          quantity: item.quantity,
          lineTotal: item.line_total.to_f
        }
      end
    }
  end
end
