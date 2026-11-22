class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rating, null: false
      t.string  :comment, limit: 1000
      t.timestamps

      t.check_constraint "rating BETWEEN 1 AND 5", name: "reviews_rating_allowed"
    end

    add_index :reviews, [ :product_id, :user_id ], unique: true
  end
end
