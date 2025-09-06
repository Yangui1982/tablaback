class AddUniqueIndexOnProjectsUserIdTitle < ActiveRecord::Migration[7.1]
  def change
    add_index :projects, [:user_id, :title], unique: true, name: "index_projects_on_user_id_and_title"
  end
end
