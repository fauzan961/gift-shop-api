class ExpireUnpaidOrdersJob < ApplicationJob
  def perform
    OrderService.new.expire_unpaid
  end
end
