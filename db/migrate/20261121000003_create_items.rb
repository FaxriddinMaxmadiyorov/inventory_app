class CreateItems < ActiveRecord::Migration[8.0]
  SLOTS = (1..3).freeze

  def change
    create_table :items do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :custom_id, null: false
      t.integer :sequence, null: false, default: 0

      SLOTS.each { |n| t.string "custom_string#{n}" }
      SLOTS.each { |n| t.text "custom_text#{n}" }
      SLOTS.each { |n| t.decimal "custom_number#{n}" }
      SLOTS.each { |n| t.string "custom_link#{n}" }
      SLOTS.each { |n| t.boolean "custom_bool#{n}", null: false, default: false }
      SLOTS.each { |n| t.string "custom_select#{n}" }

      t.integer :likes_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.text :search_text
      t.timestamps
    end

    # The custom ID is unique inside one inventory, enforced by the database.
    add_index :items, %i[inventory_id custom_id], unique: true
    add_index :items, %i[inventory_id sequence]
    add_index :items, %i[inventory_id created_at]
    add_index :items, "to_tsvector('simple', regexp_replace(coalesce(search_text, ''), '[^[:alnum:]]+', ' ', 'g'))", using: :gin, name: "index_items_on_search"

    create_table :likes do |t|
      t.references :item, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
    add_index :likes, %i[item_id user_id], unique: true
  end
end
