class CreateLoginCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :login_codes do |t|
      t.string   :mobile, null: false, limit: 8
      t.string   :code_digest, null: false, limit: 64
      t.datetime :expires_at, null: false
      t.integer  :attempts, null: false, default: 0
      t.datetime :consumed_at
      t.timestamps

      t.check_constraint "mobile ~ '^[569][0-9]{7}$'", name: "login_codes_mobile_format"
      t.check_constraint "attempts >= 0", name: "login_codes_attempts_not_negative"
    end

    add_index :login_codes, [ :mobile, :created_at ]
  end
end
