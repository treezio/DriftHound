class AddBranchToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :branch, :string, default: "main"
  end
end
