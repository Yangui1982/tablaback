class AddUniqueIndexOnTracksNamePerScore < ActiveRecord::Migration[7.1]
  def change
    add_index :tracks, [:score_id, :name],
      unique: true,
      name: :index_tracks_on_score_id_and_name
  end
end
