class CreateProductCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :product_categories do |t|
      t.references :product, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :category, null: false, foreign_key: true
      t.boolean :primary_category, null: false, default: false
      t.timestamps
    end

    add_index :product_categories, [ :product_id, :category_id ], unique: true
    add_index :product_categories, :product_id, unique: true, where: "primary_category",
              name: "index_product_categories_one_primary_per_product"
  end
end
