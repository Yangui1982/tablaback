class AddMidiChannelCheckConstraintToTracks < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      ALTER TABLE tracks
      ADD CONSTRAINT midi_channel_range_check
      CHECK (midi_channel IS NULL OR (midi_channel >= 1 AND midi_channel <= 16))
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE tracks
      DROP CONSTRAINT IF EXISTS midi_channel_range_check
    SQL
  end
end
