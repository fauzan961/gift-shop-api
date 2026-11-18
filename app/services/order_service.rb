class OrderService
  MAX_DAYS_AHEAD = 30
  MAX_TOTAL = BigDecimal("5000")
  PAYMENT_WINDOW = 30.minutes

  class CartChanged < StandardError; end

  def place(user, items:, expected_total:, details:)
    cart = CartService.new.check(items)
    if cart[:lines].empty? || cart[:unavailable].any? || cart[:total] != BigDecimal(expected_total.to_s, exception: false)
      raise CartChanged, "Your cart has changed. Please review it before paying."
    end

    order = build_order(user, cart, details)
    order.validate
    check_delivery(order)
    check_total(order)
    raise ActiveRecord::RecordInvalid, order if order.errors.any?

    Order.transaction(requires_new: true) do
      reserve_stock!(cart[:lines])
      order.save!
    end
    order
  end

  def expire_unpaid
    Order.where(status: "pending_payment", created_at: ...PAYMENT_WINDOW.ago).find_each do |order|
      order.with_lock do
        next unless order.status == "pending_payment"

        order.order_items.each do |item|
          Product.where(id: item.product_id).update_all([ "stock = stock + ?", item.quantity ])
        end
        order.update!(status: "expired")
      end
    end
  end

  private
    def build_order(user, cart, details)
      order = user.orders.build(details)
      order.assign_attributes(number: generate_number, subtotal: cart[:subtotal], delivery_fee: cart[:delivery_fee], total: cart[:total])

      cart[:lines].each do |line|
        product = line[:product]
        order.order_items.build(
          product: product, product_name_en: product.name_en, product_name_ar: product.name_ar,
          unit_price: product.price, quantity: line[:quantity], line_total: product.price * line[:quantity]
        )
      end
      order
    end

    def check_delivery(order)
      return if order.delivery_date.nil?

      if order.delivery_date < Date.current || order.delivery_date > MAX_DAYS_AHEAD.days.from_now.to_date
        order.errors.add(:delivery_date, "must be between today and #{MAX_DAYS_AHEAD} days from now")
      elsif order.delivery_date == Date.current && Order::DELIVERY_SLOTS.include?(order.delivery_slot) &&
            order.delivery_slot.to_i <= Time.current.hour
        order.errors.add(:delivery_slot, "has already started today")
      end
    end

    def check_total(order)
      order.errors.add(:total, "must be at most #{MAX_TOTAL.to_i} KWD") if order.total > MAX_TOTAL
    end

    def reserve_stock!(lines)
      lines.sort_by { |line| line[:product].id }.each do |line|
        reserved = Product.where(id: line[:product].id, stock: line[:quantity]..)
                          .update_all([ "stock = stock - ?", line[:quantity] ])
        raise CartChanged, "Your cart has changed. Please review it before paying." if reserved.zero?
      end
    end

    def generate_number
      loop do
        number = "#{Time.current.strftime('%y%m%d')}#{SecureRandom.random_number(100_000).to_s.rjust(5, '0')}"
        return number unless Order.exists?(number: number)
      end
    end
end
