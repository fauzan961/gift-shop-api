class AddExpiredToOrderStatuses < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :orders, "status IN ('pending_payment', 'preparing', 'on_the_way', 'delivered', 'cancelled')",
                            name: "orders_status_allowed"
    add_check_constraint :orders, "status IN ('pending_payment', 'expired', 'preparing', 'on_the_way', 'delivered', 'cancelled')",
                         name: "orders_status_allowed"
  end
end
