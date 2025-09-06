class HardenScoresTitleConstraints < ActiveRecord::Migration[7.1]
  def up
    change_column_null :scores, :title, false
    add_check_constraint :scores, "char_length(title) <= 200", name: "scores_title_maxlen"
  end

  def down
    remove_check_constraint :scores, name: "scores_title_maxlen"
    change_column_null :scores, :title, true
  end
end
