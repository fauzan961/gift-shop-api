class CartsController < ApplicationController
  allow_unauthenticated_access

  def check
    cart = CartService.new.check(params.permit(items: [ :slug, :quantity ])[:items])
    product_serializer = ProductSerializer.new

    render json: {
      data: {
        items: cart[:lines].map do |line|
          {
            product: product_serializer.serialize(line[:product]),
            quantity: line[:quantity],
            lineTotal: (line[:product].price * line[:quantity]).to_f
          }
        end,
        unavailable: cart[:unavailable],
        subtotal: cart[:subtotal].to_f,
        deliveryFee: cart[:delivery_fee].to_f,
        total: cart[:total].to_f
      }
    }
  end
end
