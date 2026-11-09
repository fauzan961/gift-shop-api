class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string  :address_type, null: false, limit: 10
      t.string  :address, null: false, limit: 255
      t.string  :block_area, null: false, limit: 100
      t.string  :city, null: false, limit: 100
      t.boolean :is_default, null: false, default: false
      t.timestamps

      t.check_constraint "address_type IN ('Home', 'Work', 'Other')", name: "addresses_address_type_allowed"
    end

    add_index :addresses, :user_id, unique: true, where: "is_default", name: "index_addresses_on_user_id_default"
  end
end
