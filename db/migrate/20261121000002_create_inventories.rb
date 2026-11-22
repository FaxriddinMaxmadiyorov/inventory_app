class CreateInventories < ActiveRecord::Migration[8.0]
  # Every inventory has a fixed set of custom field slots: three per type.
  # The inventory only stores whether a slot is used and how it is presented;
  # the values live in the matching columns of the items table.
  FIELD_KINDS = %w[string text number link bool select].freeze
  SLOTS = (1..3).freeze

  def change
    create_table :categories do |t|
      t.string :name, null: false
    end
    add_index :categories, :name, unique: true

    create_table :inventories do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.text :description
      t.string :image_url
      t.boolean :is_public, null: false, default: false
      t.integer :items_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.text :search_text

      FIELD_KINDS.each do |kind|
        SLOTS.each do |n|
          prefix = "custom_#{kind}#{n}"
          t.boolean "#{prefix}_state", null: false, default: false
          t.string "#{prefix}_name"
          t.string "#{prefix}_description"
          t.boolean "#{prefix}_show", null: false, default: true
          t.integer "#{prefix}_position", null: false, default: 0

          case kind
          when "string"
            t.integer "#{prefix}_max_length"
            t.string "#{prefix}_pattern"
          when "number"
            t.decimal "#{prefix}_min"
            t.decimal "#{prefix}_max"
          when "select"
            t.text "#{prefix}_options"
          end
        end
      end

      t.timestamps
    end
    add_index :inventories, :created_at
    add_index :inventories, :items_count
    add_index :inventories, "to_tsvector('simple', regexp_replace(coalesce(search_text, ''), '[^[:alnum:]]+', ' ', 'g'))", using: :gin, name: "index_inventories_on_search"

    create_table :id_elements do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.string :kind, null: false
      t.string :format, null: false, default: ""
    end

    create_table :tags do |t|
      t.string :name, null: false
    end
    add_index :tags, :name, unique: true
    add_index :tags, "name text_pattern_ops", name: "index_tags_on_name_prefix"

    create_table :inventory_tags do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :inventory_tags, %i[inventory_id tag_id], unique: true

    create_table :inventory_accesses do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :inventory_accesses, %i[inventory_id user_id], unique: true

    create_table :posts do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text :body, null: false
      t.datetime :created_at, null: false
    end
  end
end
