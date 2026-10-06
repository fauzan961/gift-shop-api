class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string  :name_en, null: false, limit: 50
      t.string  :name_ar, limit: 50
      t.string  :slug, null: false, limit: 60
      t.string  :emoji
      t.string  :tagline_en, limit: 120
      t.string  :tagline_ar, limit: 120
      t.string  :image
      t.string  :theme
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps

      t.check_constraint "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "categories_slug_format"
    end

    add_index :categories, :name_en, unique: true
    add_index :categories, :name_ar, unique: true
    add_index :categories, :slug, unique: true
  end
end
