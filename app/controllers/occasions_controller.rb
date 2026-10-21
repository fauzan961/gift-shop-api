class OccasionsController < ApplicationController
  def index
    occasions = Occasion.active.ordered
    render json: { data: OccasionSerializer.new.serialize_collection(occasions, Occasion.active_product_counts) }
  end
end
