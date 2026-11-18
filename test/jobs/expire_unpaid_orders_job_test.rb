require "test_helper"

class ExpireUnpaidOrdersJobTest < ActiveJob::TestCase
  test "expires unpaid orders and returns their stock" do
    ExpireUnpaidOrdersJob.perform_now

    assert_equal "expired", orders(:layla_pending_payment).reload.status
    assert_equal 1, products(:teddy_bear).reload.stock
  end
end
