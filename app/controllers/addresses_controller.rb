class AddressesController < ApplicationController
  def index
    addresses = Current.user.addresses.order(is_default: :desc, id: :asc)
    render json: { data: addresses.map { |address| AddressSerializer.new.serialize(address) } }
  end

  def create
    address = AddressService.new.create(Current.user, address_params)
    render json: { data: AddressSerializer.new.serialize(address) }, status: :created
  rescue AddressService::LimitReached => error
    render_error(:unprocessable_content, "address_limit_reached", error.message)
  end

  def update
    address = AddressService.new.update(Current.user.addresses.find(params[:id]), address_params)
    render json: { data: AddressSerializer.new.serialize(address) }
  end

  def destroy
    AddressService.new.destroy(Current.user.addresses.find(params[:id]))
    head :no_content
  end

  private
    def address_params
      params.permit(:address_type, :address, :block_area, :city, :is_default)
    end
end
