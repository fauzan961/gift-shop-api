class AddDiscountToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :original_price, :decimal, precision: 10, scale: 3, null: false
    add_column :order_items, :discount_amount, :decimal, precision: 10, scale: 3, null: false, default: 0

    add_check_constraint :order_items, "discount_amount >= 0", name: "order_items_discount_amount_not_negative"
    add_check_constraint :order_items, "original_price = unit_price + discount_amount", name: "order_items_original_price_adds_up"
  end
end
