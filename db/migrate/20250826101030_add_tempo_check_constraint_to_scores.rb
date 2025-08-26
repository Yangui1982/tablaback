class AddTempoCheckConstraintToScores < ActiveRecord::Migration[7.1]
  def up
    add_check_constraint :scores, "tempo IS NULL OR tempo > 0", name: "scores_tempo_positive"
  end

  def down
    remove_check_constraint :scores, name: "scores_tempo_positive"
  end
end
