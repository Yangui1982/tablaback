class AddTracksCountToScores < ActiveRecord::Migration[7.1]
  def up
    add_column :scores, :tracks_count, :integer, null: false, default: 0
    add_index  :scores, :tracks_count

    execute <<~SQL.squish
      UPDATE scores
      SET tracks_count = sub.cnt
      FROM (
        SELECT score_id, COUNT(*) AS cnt
        FROM tracks
        GROUP BY score_id
      ) AS sub
      WHERE sub.score_id = scores.id;
    SQL
  end

  def down
    remove_index  :scores, :tracks_count
    remove_column :scores, :tracks_count
  end
end
