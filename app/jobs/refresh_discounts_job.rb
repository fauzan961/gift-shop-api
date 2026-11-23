class RefreshDiscountsJob < ApplicationJob
  def perform
    DiscountService.new.refresh
  end
end
