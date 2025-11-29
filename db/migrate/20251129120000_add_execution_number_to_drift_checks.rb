class AddExecutionNumberToDriftChecks < ActiveRecord::Migration[7.1]
  def change
    add_column :drift_checks, :execution_number, :integer
    add_index :drift_checks, [ :environment_id, :execution_number ], unique: true
  end
end
