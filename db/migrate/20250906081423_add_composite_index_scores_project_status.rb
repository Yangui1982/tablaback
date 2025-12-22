class AddCompositeIndexScoresProjectStatus < ActiveRecord::Migration[7.1]
  def change
    add_index :scores, [:project_id, :status], name: "index_scores_on_project_id_and_status"
  end
end
