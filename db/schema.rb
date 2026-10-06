# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_05_130113) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name_en", limit: 50, null: false
    t.string "name_ar", limit: 50
    t.string "slug", limit: 60, null: false
    t.string "emoji"
    t.string "tagline_en", limit: 120
    t.string "tagline_ar", limit: 120
    t.string "image"
    t.string "theme"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name_ar"], name: "index_categories_on_name_ar", unique: true
    t.index ["name_en"], name: "index_categories_on_name_en", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "categories_slug_format"
  end
end
