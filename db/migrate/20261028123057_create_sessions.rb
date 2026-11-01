class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string   :token_digest, null: false, limit: 64
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.string   :ip_address, limit: 45
      t.string   :user_agent, limit: 255
      t.timestamps
    end

    add_index :sessions, :token_digest, unique: true
  end
end
