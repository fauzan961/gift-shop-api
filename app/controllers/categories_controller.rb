class CategoriesController < ApplicationController
  def index
    categories = Category.active.ordered
    render json: { data: CategorySerializer.new.serialize_collection(categories) }
  end
end
