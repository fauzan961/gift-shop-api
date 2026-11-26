module Admin
  class ProductsController < Admin::ApplicationController
    def create
      super
      DiscountService.new.refresh
    end

    def update
      super
      DiscountService.new.refresh
    end
  end
end
