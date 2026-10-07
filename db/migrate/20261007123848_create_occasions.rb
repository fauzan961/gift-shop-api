class CreateOccasions < ActiveRecord::Migration[8.1]
  def change
    create_table :occasions do |t|
      t.string  :name_en, null: false, limit: 50
      t.string  :name_ar, limit: 50
      t.string  :slug, null: false, limit: 60
      t.string  :emoji
      t.string  :tagline_en, limit: 120
      t.string  :tagline_ar, limit: 120
      t.string  :image
      t.date    :occurs_on
      t.boolean :featured, null: false, default: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps

      t.check_constraint "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "occasions_slug_format"
    end

    add_index :occasions, :name_en, unique: true
    add_index :occasions, :name_ar, unique: true
    add_index :occasions, :slug, unique: true
  end
end
