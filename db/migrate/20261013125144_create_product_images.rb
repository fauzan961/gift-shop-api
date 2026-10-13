class CreateProductImages < ActiveRecord::Migration[8.1]
  def change
    create_table :product_images do |t|
      t.references :product, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string  :image, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :product_images, [ :product_id, :position ]
  end
end
