class FavoritesController < ApplicationController
  def index
    favorites = Current.user.favorites.joins(:product).merge(Product.active)
                       .includes(product: [ :primary_category, :product_images ])
                       .order(created_at: :desc, id: :desc)

    render json: { data: ProductSerializer.new.serialize_collection(favorites.map(&:product)) }
  end

  def create
    product = Product.active.find_by!(slug: slug)
    Current.user.favorites.insert({ product_id: product.id })
    head :no_content
  end

  def destroy
    Current.user.favorites.where(product: Product.where(slug: slug)).delete_all
    head :no_content
  end

  private
    def slug
      params[:slug].to_s.downcase
    end
end
