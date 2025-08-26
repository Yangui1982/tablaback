class RenameChannelToMidiChannelInTracks < ActiveRecord::Migration[7.1]
  def up
    if column_exists?(:tracks, :channel) && !column_exists?(:tracks, :midi_channel)
      rename_column :tracks, :channel, :midi_channel
    end

    if column_exists?(:tracks, :midi_channel)
      change_column :tracks, :midi_channel, :integer, using: 'midi_channel::integer'
    end

    add_check_constraint :tracks,
      'midi_channel IS NULL OR (midi_channel >= 0 AND midi_channel <= 15)',
      name: 'tracks_midi_channel_range'

    add_index :tracks, :midi_channel unless index_exists?(:tracks, :midi_channel)
  end

  def down
    remove_check_constraint :tracks, name: 'tracks_midi_channel_range' rescue nil
    remove_index :tracks, :midi_channel if index_exists?(:tracks, :midi_channel)
    change_column :tracks, :midi_channel, :string if column_exists?(:tracks, :midi_channel)

    if column_exists?(:tracks, :midi_channel) && !column_exists?(:tracks, :channel)
      rename_column :tracks, :midi_channel, :channel
    end
  end
end
