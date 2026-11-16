class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string  :number, null: false, limit: 25
      t.string  :status, null: false, default: "pending_payment", limit: 20

      t.string  :recipient_name, null: false, limit: 100
      t.string  :address, null: false, limit: 255
      t.string  :block_area, null: false, limit: 100
      t.string  :city, null: false, limit: 100
      t.date    :delivery_date, null: false
      t.string  :delivery_slot, null: false, limit: 10
      t.string  :gift_message, limit: 200
      t.string  :payment_method, null: false, limit: 20

      t.decimal :subtotal, null: false, precision: 10, scale: 3
      t.decimal :delivery_fee, null: false, precision: 10, scale: 3
      t.decimal :total, null: false, precision: 10, scale: 3
      t.timestamps

      t.check_constraint "status IN ('pending_payment', 'preparing', 'on_the_way', 'delivered', 'cancelled')",
                         name: "orders_status_allowed"
      t.check_constraint "delivery_slot IN ('09-12', '12-15', '15-18', '18-21')", name: "orders_delivery_slot_allowed"
      t.check_constraint "payment_method IN ('mpgs', 'knet', 'apple_pay')", name: "orders_payment_method_allowed"
      t.check_constraint "subtotal > 0 AND delivery_fee >= 0 AND total = subtotal + delivery_fee", name: "orders_totals_add_up"
    end

    add_index :orders, :number, unique: true
    add_index :orders, [ :user_id, :created_at ]
  end
end
