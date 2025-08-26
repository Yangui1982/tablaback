class AddDbIndexesToScores < ActiveRecord::Migration[7.1]
  def change
    add_index :scores, [:project_id, :title], unique: true, name: "index_scores_on_project_id_and_title"
    add_index :scores, :status
  end
end
