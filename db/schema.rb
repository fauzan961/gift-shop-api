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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_122812) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address_type", limit: 10, null: false
    t.string "address", limit: 255, null: false
    t.string "block_area", limit: 100, null: false
    t.string "city", limit: 100, null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.index ["user_id"], name: "index_addresses_on_user_id_default", unique: true, where: "is_default"
    t.check_constraint "address_type::text = ANY (ARRAY['Home'::character varying, 'Work'::character varying, 'Other'::character varying]::text[])", name: "addresses_address_type_allowed"
  end

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

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_favorites_on_product_id"
    t.index ["user_id", "product_id"], name: "index_favorites_on_user_id_and_product_id", unique: true
  end

  create_table "login_codes", force: :cascade do |t|
    t.string "mobile", limit: 8, null: false
    t.string "code_digest", limit: 64, null: false
    t.datetime "expires_at", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mobile", "created_at"], name: "index_login_codes_on_mobile_and_created_at"
    t.check_constraint "attempts >= 0", name: "login_codes_attempts_not_negative"
    t.check_constraint "mobile::text ~ '^[569][0-9]{7}$'::text", name: "login_codes_mobile_format"
  end

  create_table "occasions", force: :cascade do |t|
    t.string "name_en", limit: 50, null: false
    t.string "name_ar", limit: 50
    t.string "slug", limit: 60, null: false
    t.string "emoji"
    t.string "tagline_en", limit: 120
    t.string "tagline_ar", limit: 120
    t.string "image"
    t.date "occurs_on"
    t.boolean "featured", default: false, null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name_ar"], name: "index_occasions_on_name_ar", unique: true
    t.index ["name_en"], name: "index_occasions_on_name_en", unique: true
    t.index ["slug"], name: "index_occasions_on_slug", unique: true
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "occasions_slug_format"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id"
    t.string "product_name_en", limit: 100, null: false
    t.string "product_name_ar", limit: 100
    t.decimal "unit_price", precision: 10, scale: 3, null: false
    t.integer "quantity", null: false
    t.decimal "line_total", precision: 10, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id"], name: "index_order_items_on_order_id_and_product_id", unique: true
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "line_total = (unit_price * quantity::numeric)", name: "order_items_line_total_adds_up"
    t.check_constraint "quantity >= 1 AND quantity <= 99", name: "order_items_quantity_allowed"
    t.check_constraint "unit_price > 0::numeric", name: "order_items_unit_price_positive"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "number", limit: 25, null: false
    t.string "status", limit: 20, default: "pending_payment", null: false
    t.string "recipient_name", limit: 100, null: false
    t.string "address", limit: 255, null: false
    t.string "block_area", limit: 100, null: false
    t.string "city", limit: 100, null: false
    t.date "delivery_date", null: false
    t.string "delivery_slot", limit: 10, null: false
    t.string "gift_message", limit: 200
    t.string "payment_method", limit: 20, null: false
    t.decimal "subtotal", precision: 10, scale: 3, null: false
    t.decimal "delivery_fee", precision: 10, scale: 3, null: false
    t.decimal "total", precision: 10, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["user_id", "created_at"], name: "index_orders_on_user_id_and_created_at"
    t.check_constraint "delivery_slot::text = ANY (ARRAY['09-12'::character varying, '12-15'::character varying, '15-18'::character varying, '18-21'::character varying]::text[])", name: "orders_delivery_slot_allowed"
    t.check_constraint "payment_method::text = ANY (ARRAY['mpgs'::character varying, 'knet'::character varying, 'apple_pay'::character varying]::text[])", name: "orders_payment_method_allowed"
    t.check_constraint "status::text = ANY (ARRAY['pending_payment'::character varying, 'expired'::character varying, 'preparing'::character varying, 'on_the_way'::character varying, 'delivered'::character varying, 'cancelled'::character varying]::text[])", name: "orders_status_allowed"
    t.check_constraint "subtotal > 0::numeric AND delivery_fee >= 0::numeric AND total = (subtotal + delivery_fee)", name: "orders_totals_add_up"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "category_id", null: false
    t.boolean "primary_category", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id", "category_id"], name: "index_product_categories_on_product_id_and_category_id", unique: true
    t.index ["product_id"], name: "index_product_categories_one_primary_per_product", unique: true, where: "primary_category"
  end

  create_table "product_images", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "image", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_product_images_on_product_id_and_position"
  end

  create_table "product_occasions", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "occasion_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["occasion_id"], name: "index_product_occasions_on_occasion_id"
    t.index ["product_id", "occasion_id"], name: "index_product_occasions_on_product_id_and_occasion_id", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name_en", limit: 100, null: false
    t.string "name_ar", limit: 100
    t.string "slug", limit: 120, null: false
    t.text "description_en"
    t.text "description_ar"
    t.decimal "price", precision: 10, scale: 3, null: false
    t.string "gender", limit: 10, default: "unisex", null: false
    t.string "age_group", limit: 10
    t.integer "stock", default: 0, null: false
    t.decimal "rating_average", precision: 2, scale: 1, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.check_constraint "gender::text = ANY (ARRAY['men'::character varying, 'women'::character varying, 'unisex'::character varying]::text[])", name: "products_gender_allowed"
    t.check_constraint "price > 0::numeric", name: "products_price_positive"
    t.check_constraint "rating_average >= 0::numeric AND rating_average <= 5::numeric", name: "products_rating_average_range"
    t.check_constraint "reviews_count >= 0", name: "products_reviews_count_not_negative"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "products_slug_format"
    t.check_constraint "stock >= 0", name: "products_stock_not_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", limit: 64, null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.string "ip_address", limit: 45
    t.string "user_agent", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "mobile", limit: 8, null: false
    t.string "full_name", limit: 100
    t.string "email", limit: 255
    t.date "birthday"
    t.boolean "order_sms", default: true, null: false
    t.boolean "occasion_reminders", default: true, null: false
    t.boolean "offers_email", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["mobile"], name: "index_users_on_mobile", unique: true
    t.check_constraint "mobile::text ~ '^[569][0-9]{7}$'::text", name: "users_mobile_format"
  end

  add_foreign_key "addresses", "users", on_delete: :cascade
  add_foreign_key "favorites", "products", on_delete: :cascade
  add_foreign_key "favorites", "users", on_delete: :cascade
  add_foreign_key "order_items", "orders", on_delete: :cascade
  add_foreign_key "order_items", "products", on_delete: :nullify
  add_foreign_key "orders", "users"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products", on_delete: :cascade
  add_foreign_key "product_images", "products", on_delete: :cascade
  add_foreign_key "product_occasions", "occasions"
  add_foreign_key "product_occasions", "products", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
end
