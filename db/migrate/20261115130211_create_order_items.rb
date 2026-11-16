class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :product, foreign_key: { on_delete: :nullify }
      t.string  :product_name_en, null: false, limit: 100
      t.string  :product_name_ar, limit: 100
      t.decimal :unit_price, null: false, precision: 10, scale: 3
      t.integer :quantity, null: false
      t.decimal :line_total, null: false, precision: 10, scale: 3
      t.timestamps

      t.check_constraint "unit_price > 0", name: "order_items_unit_price_positive"
      t.check_constraint "quantity BETWEEN 1 AND 99", name: "order_items_quantity_allowed"
      t.check_constraint "line_total = unit_price * quantity", name: "order_items_line_total_adds_up"
    end

    add_index :order_items, [ :order_id, :product_id ], unique: true
  end
end
