class AddUniqueIndexesToTracks < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    unless index_exists?(:tracks, [:score_id, :name], unique: true, name: 'index_tracks_on_score_id_and_name')
      add_index :tracks, [:score_id, :name],
                unique: true,
                name: 'index_tracks_on_score_id_and_name',
                algorithm: :concurrently
    end

    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS
      index_tracks_on_score_id_and_midi_channel_unique
      ON tracks (score_id, midi_channel)
      WHERE midi_channel IS NOT NULL;
    SQL
  end

  def down
    remove_index :tracks, name: 'index_tracks_on_score_id_and_name' if index_exists?(:tracks, name: 'index_tracks_on_score_id_and_name')

    execute <<~SQL
      DROP INDEX IF EXISTS index_tracks_on_score_id_and_midi_channel_unique;
    SQL
  end
end
