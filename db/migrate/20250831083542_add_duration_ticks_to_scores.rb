class AddDurationTicksToScores < ActiveRecord::Migration[7.1]
  def change
    add_column :scores, :duration_ticks, :integer, default: 0, null: false
    add_index  :scores, :duration_ticks
  end
end
