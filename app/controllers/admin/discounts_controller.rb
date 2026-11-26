module Admin
  class DiscountsController < Admin::ApplicationController
    def create
      super
      DiscountService.new.refresh
    end

    def update
      super
      DiscountService.new.refresh
    end

    def destroy
      super
      DiscountService.new.refresh
    end
  end
end
