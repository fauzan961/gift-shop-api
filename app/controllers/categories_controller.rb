class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def index
    categories = Category.active.ordered
    render json: { data: CategorySerializer.new.serialize_collection(categories, Category.active_product_stats) }
  end
end
