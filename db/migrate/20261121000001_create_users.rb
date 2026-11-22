class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :encrypted_password, null: false, default: ""
      t.boolean :admin, null: false, default: false
      t.boolean :blocked, null: false, default: false
      t.string :locale
      t.string :theme

      # OAuth
      t.string :provider
      t.string :uid

      # Devise: recoverable, rememberable, confirmable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    add_index :users, %i[provider uid], unique: true
    # Prefix lookups for the user autocomplete (LIKE 'abc%')
    add_index :users, "lower(name) text_pattern_ops", name: "index_users_on_lower_name"
    add_index :users, "lower(email) text_pattern_ops", name: "index_users_on_lower_email"
  end
end
