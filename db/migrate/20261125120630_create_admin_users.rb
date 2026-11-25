class CreateAdminUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string  :name, null: false, limit: 100
      t.string  :email, null: false, limit: 255
      t.string  :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :admin_users, "lower(email)", unique: true, name: "index_admin_users_on_lower_email"
  end
end
