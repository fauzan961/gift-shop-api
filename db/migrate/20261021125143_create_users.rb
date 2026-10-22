class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :mobile, null: false, limit: 8
      t.string  :full_name, limit: 100
      t.string  :email, limit: 255
      t.date    :birthday
      t.boolean :order_sms, null: false, default: true
      t.boolean :occasion_reminders, null: false, default: true
      t.boolean :offers_email, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps

      t.check_constraint "mobile ~ '^[569][0-9]{7}$'", name: "users_mobile_format"
    end

    add_index :users, :mobile, unique: true
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
  end
end
