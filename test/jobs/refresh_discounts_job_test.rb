require "test_helper"

class RefreshDiscountsJobTest < ActiveJob::TestCase
  test "applies the running discounts to product prices" do
    RefreshDiscountsJob.perform_now

    product = products(:chocolate_box).reload
    assert_equal [ BigDecimal("10.0"), 20 ], [ product.sale_price, product.discount_percent ]
  end
end
