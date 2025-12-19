class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.string :token, null: false
      t.string :email, null: false
      t.integer :role, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :invites, :token, unique: true
    add_index :invites, :email
  end
end
