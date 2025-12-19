class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, default: 0, null: false

    # Migrate existing data: admin users become role 2 (admin), others become role 0 (viewer)
    execute <<-SQL
      UPDATE users SET role = 2 WHERE admin = true;
      UPDATE users SET role = 0 WHERE admin = false;
    SQL

    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, default: false, null: false

    execute <<-SQL
      UPDATE users SET admin = true WHERE role = 2;
      UPDATE users SET admin = false WHERE role IN (0, 1);
    SQL

    remove_column :users, :role
  end
end
