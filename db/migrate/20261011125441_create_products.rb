class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string  :name_en, null: false, limit: 100
      t.string  :name_ar, limit: 100
      t.string  :slug, null: false, limit: 120
      t.text    :description_en
      t.text    :description_ar
      t.decimal :price, null: false, precision: 10, scale: 3
      t.string  :gender, null: false, default: "unisex", limit: 10
      t.string  :age_group, limit: 10
      t.integer :stock, null: false, default: 0
      t.decimal :rating_average, null: false, default: 0, precision: 2, scale: 1
      t.integer :reviews_count, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps

      t.check_constraint "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "products_slug_format"
      t.check_constraint "price > 0", name: "products_price_positive"
      t.check_constraint "gender IN ('men', 'women', 'unisex')", name: "products_gender_allowed"
      t.check_constraint "stock >= 0", name: "products_stock_not_negative"
      t.check_constraint "rating_average BETWEEN 0 AND 5", name: "products_rating_average_range"
      t.check_constraint "reviews_count >= 0", name: "products_reviews_count_not_negative"
    end

    add_index :products, :slug, unique: true
  end
end
