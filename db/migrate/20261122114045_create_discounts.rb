class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string   :name, null: false, limit: 100
      t.string   :discount_type, null: false, limit: 10
      t.decimal  :value, null: false, precision: 10, scale: 3
      t.string   :applies_to, null: false, limit: 10
      t.references :category, foreign_key: { on_delete: :cascade }
      t.references :occasion, foreign_key: { on_delete: :cascade }
      t.references :product, foreign_key: { on_delete: :cascade }
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean  :active, null: false, default: true
      t.timestamps

      t.check_constraint "discount_type IN ('percentage', 'amount')", name: "discounts_type_allowed"
      t.check_constraint "(discount_type = 'percentage' AND value BETWEEN 1 AND 100) OR (discount_type = 'amount' AND value > 0)",
                         name: "discounts_value_allowed"
      t.check_constraint "applies_to IN ('all', 'category', 'occasion', 'product')", name: "discounts_applies_to_allowed"
      t.check_constraint "ends_at IS NULL OR ends_at > starts_at", name: "discounts_ends_after_start"
    end

    add_index :discounts, [ :active, :starts_at, :ends_at ]
  end
end
