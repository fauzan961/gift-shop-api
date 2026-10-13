class CreateProductOccasions < ActiveRecord::Migration[8.1]
  def change
    create_table :product_occasions do |t|
      t.references :product, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :occasion, null: false, foreign_key: true
      t.timestamps
    end

    add_index :product_occasions, [ :product_id, :occasion_id ], unique: true
  end
end
