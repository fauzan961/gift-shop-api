class OrdersController < ApplicationController
  def index
    orders = Current.user.orders.where.not(status: %w[ pending_payment expired ])
                    .includes(order_items: { product: [ :primary_category, :product_images ] })
                    .order(created_at: :desc)
    render json: { data: orders.map { |order| OrderSerializer.new.serialize(order) } }
  end

  def show
    order = Current.user.orders.includes(order_items: { product: [ :primary_category, :product_images ] })
                        .find_by!(number: params[:number])
    render json: { data: OrderSerializer.new.serialize(order) }
  end

  def create
    order = OrderService.new.place(Current.user, items: params.permit(items: [ :slug, :quantity ])[:items],
                                   expected_total: params[:expected_total], details: order_details)
    render json: { data: OrderSerializer.new.serialize(order) }, status: :created
  rescue OrderService::CartChanged => error
    render_error(:conflict, "cart_changed", error.message)
  end

  private
    def order_details
      params.permit(:recipient_name, :address, :block_area, :city, :delivery_date, :delivery_slot, :gift_message, :payment_method)
    end
end
