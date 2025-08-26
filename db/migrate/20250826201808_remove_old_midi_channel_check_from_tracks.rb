class RemoveOldMidiChannelCheckFromTracks < ActiveRecord::Migration[7.1]
  def change
    remove_check_constraint :tracks, name: "tracks_midi_channel_range"
  end
end
