class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.boolean :admin, default: false, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
