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

ActiveRecord::Schema[8.0].define(version: 2026_11_21_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "id_elements", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.integer "position", default: 0, null: false
    t.string "kind", null: false
    t.string "format", default: "", null: false
    t.index ["inventory_id"], name: "index_id_elements_on_inventory_id"
  end

  create_table "inventories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id"
    t.string "title", null: false
    t.text "description"
    t.string "image_url"
    t.boolean "is_public", default: false, null: false
    t.integer "items_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.text "search_text"
    t.boolean "custom_string1_state", default: false, null: false
    t.string "custom_string1_name"
    t.string "custom_string1_description"
    t.boolean "custom_string1_show", default: true, null: false
    t.integer "custom_string1_position", default: 0, null: false
    t.integer "custom_string1_max_length"
    t.string "custom_string1_pattern"
    t.boolean "custom_string2_state", default: false, null: false
    t.string "custom_string2_name"
    t.string "custom_string2_description"
    t.boolean "custom_string2_show", default: true, null: false
    t.integer "custom_string2_position", default: 0, null: false
    t.integer "custom_string2_max_length"
    t.string "custom_string2_pattern"
    t.boolean "custom_string3_state", default: false, null: false
    t.string "custom_string3_name"
    t.string "custom_string3_description"
    t.boolean "custom_string3_show", default: true, null: false
    t.integer "custom_string3_position", default: 0, null: false
    t.integer "custom_string3_max_length"
    t.string "custom_string3_pattern"
    t.boolean "custom_text1_state", default: false, null: false
    t.string "custom_text1_name"
    t.string "custom_text1_description"
    t.boolean "custom_text1_show", default: true, null: false
    t.integer "custom_text1_position", default: 0, null: false
    t.boolean "custom_text2_state", default: false, null: false
    t.string "custom_text2_name"
    t.string "custom_text2_description"
    t.boolean "custom_text2_show", default: true, null: false
    t.integer "custom_text2_position", default: 0, null: false
    t.boolean "custom_text3_state", default: false, null: false
    t.string "custom_text3_name"
    t.string "custom_text3_description"
    t.boolean "custom_text3_show", default: true, null: false
    t.integer "custom_text3_position", default: 0, null: false
    t.boolean "custom_number1_state", default: false, null: false
    t.string "custom_number1_name"
    t.string "custom_number1_description"
    t.boolean "custom_number1_show", default: true, null: false
    t.integer "custom_number1_position", default: 0, null: false
    t.decimal "custom_number1_min"
    t.decimal "custom_number1_max"
    t.boolean "custom_number2_state", default: false, null: false
    t.string "custom_number2_name"
    t.string "custom_number2_description"
    t.boolean "custom_number2_show", default: true, null: false
    t.integer "custom_number2_position", default: 0, null: false
    t.decimal "custom_number2_min"
    t.decimal "custom_number2_max"
    t.boolean "custom_number3_state", default: false, null: false
    t.string "custom_number3_name"
    t.string "custom_number3_description"
    t.boolean "custom_number3_show", default: true, null: false
    t.integer "custom_number3_position", default: 0, null: false
    t.decimal "custom_number3_min"
    t.decimal "custom_number3_max"
    t.boolean "custom_link1_state", default: false, null: false
    t.string "custom_link1_name"
    t.string "custom_link1_description"
    t.boolean "custom_link1_show", default: true, null: false
    t.integer "custom_link1_position", default: 0, null: false
    t.boolean "custom_link2_state", default: false, null: false
    t.string "custom_link2_name"
    t.string "custom_link2_description"
    t.boolean "custom_link2_show", default: true, null: false
    t.integer "custom_link2_position", default: 0, null: false
    t.boolean "custom_link3_state", default: false, null: false
    t.string "custom_link3_name"
    t.string "custom_link3_description"
    t.boolean "custom_link3_show", default: true, null: false
    t.integer "custom_link3_position", default: 0, null: false
    t.boolean "custom_bool1_state", default: false, null: false
    t.string "custom_bool1_name"
    t.string "custom_bool1_description"
    t.boolean "custom_bool1_show", default: true, null: false
    t.integer "custom_bool1_position", default: 0, null: false
    t.boolean "custom_bool2_state", default: false, null: false
    t.string "custom_bool2_name"
    t.string "custom_bool2_description"
    t.boolean "custom_bool2_show", default: true, null: false
    t.integer "custom_bool2_position", default: 0, null: false
    t.boolean "custom_bool3_state", default: false, null: false
    t.string "custom_bool3_name"
    t.string "custom_bool3_description"
    t.boolean "custom_bool3_show", default: true, null: false
    t.integer "custom_bool3_position", default: 0, null: false
    t.boolean "custom_select1_state", default: false, null: false
    t.string "custom_select1_name"
    t.string "custom_select1_description"
    t.boolean "custom_select1_show", default: true, null: false
    t.integer "custom_select1_position", default: 0, null: false
    t.text "custom_select1_options"
    t.boolean "custom_select2_state", default: false, null: false
    t.string "custom_select2_name"
    t.string "custom_select2_description"
    t.boolean "custom_select2_show", default: true, null: false
    t.integer "custom_select2_position", default: 0, null: false
    t.text "custom_select2_options"
    t.boolean "custom_select3_state", default: false, null: false
    t.string "custom_select3_name"
    t.string "custom_select3_description"
    t.boolean "custom_select3_show", default: true, null: false
    t.integer "custom_select3_position", default: 0, null: false
    t.text "custom_select3_options"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, regexp_replace(COALESCE(search_text, ''::text), '[^[:alnum:]]+'::text, ' '::text, 'g'::text))", name: "index_inventories_on_search", using: :gin
    t.index ["category_id"], name: "index_inventories_on_category_id"
    t.index ["created_at"], name: "index_inventories_on_created_at"
    t.index ["items_count"], name: "index_inventories_on_items_count"
    t.index ["user_id"], name: "index_inventories_on_user_id"
  end

  create_table "inventory_accesses", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id", null: false
    t.index ["inventory_id", "user_id"], name: "index_inventory_accesses_on_inventory_id_and_user_id", unique: true
    t.index ["inventory_id"], name: "index_inventory_accesses_on_inventory_id"
    t.index ["user_id"], name: "index_inventory_accesses_on_user_id"
  end

  create_table "inventory_tags", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "tag_id", null: false
    t.index ["inventory_id", "tag_id"], name: "index_inventory_tags_on_inventory_id_and_tag_id", unique: true
    t.index ["inventory_id"], name: "index_inventory_tags_on_inventory_id"
    t.index ["tag_id"], name: "index_inventory_tags_on_tag_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id"
    t.string "custom_id", null: false
    t.integer "sequence", default: 0, null: false
    t.string "custom_string1"
    t.string "custom_string2"
    t.string "custom_string3"
    t.text "custom_text1"
    t.text "custom_text2"
    t.text "custom_text3"
    t.decimal "custom_number1"
    t.decimal "custom_number2"
    t.decimal "custom_number3"
    t.string "custom_link1"
    t.string "custom_link2"
    t.string "custom_link3"
    t.boolean "custom_bool1", default: false, null: false
    t.boolean "custom_bool2", default: false, null: false
    t.boolean "custom_bool3", default: false, null: false
    t.string "custom_select1"
    t.string "custom_select2"
    t.string "custom_select3"
    t.integer "likes_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.text "search_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, regexp_replace(COALESCE(search_text, ''::text), '[^[:alnum:]]+'::text, ' '::text, 'g'::text))", name: "index_items_on_search", using: :gin
    t.index ["inventory_id", "created_at"], name: "index_items_on_inventory_id_and_created_at"
    t.index ["inventory_id", "custom_id"], name: "index_items_on_inventory_id_and_custom_id", unique: true
    t.index ["inventory_id", "sequence"], name: "index_items_on_inventory_id_and_sequence"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "likes", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["item_id", "user_id"], name: "index_likes_on_item_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.index ["inventory_id"], name: "index_posts_on_inventory_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["name"], name: "index_tags_on_name_prefix", opclass: :text_pattern_ops
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "blocked", default: false, null: false
    t.string "locale"
    t.string "theme"
    t.string "provider"
    t.string "uid"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text) text_pattern_ops", name: "index_users_on_lower_email"
    t.index "lower((name)::text) text_pattern_ops", name: "index_users_on_lower_name"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "id_elements", "inventories", on_delete: :cascade
  add_foreign_key "inventories", "categories", on_delete: :nullify
  add_foreign_key "inventories", "users", on_delete: :cascade
  add_foreign_key "inventory_accesses", "inventories", on_delete: :cascade
  add_foreign_key "inventory_accesses", "users", on_delete: :cascade
  add_foreign_key "inventory_tags", "inventories", on_delete: :cascade
  add_foreign_key "inventory_tags", "tags", on_delete: :cascade
  add_foreign_key "items", "inventories", on_delete: :cascade
  add_foreign_key "items", "users", on_delete: :nullify
  add_foreign_key "likes", "items", on_delete: :cascade
  add_foreign_key "likes", "users", on_delete: :cascade
  add_foreign_key "posts", "inventories", on_delete: :cascade
  add_foreign_key "posts", "users", on_delete: :cascade
end
