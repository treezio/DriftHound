class AddDirectoryToEnvironments < ActiveRecord::Migration[8.1]
  def change
    add_column :environments, :directory, :string
  end
end
