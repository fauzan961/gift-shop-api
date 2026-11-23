class AddSalePriceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :sale_price, :decimal, precision: 10, scale: 3
    add_column :products, :discount_percent, :integer, null: false, default: 0

    reversible do |direction|
      direction.up { execute "UPDATE products SET sale_price = price" }
    end
    change_column_null :products, :sale_price, false

    add_check_constraint :products, "sale_price > 0 AND sale_price <= price", name: "products_sale_price_range"
    add_check_constraint :products, "discount_percent BETWEEN 0 AND 100", name: "products_discount_percent_range"
  end
end
