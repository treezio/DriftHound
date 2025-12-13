class AddRepositoryToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :repository, :string
  end
end
