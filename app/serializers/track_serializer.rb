class TrackSerializer < ActiveModel::Serializer
  attributes :id, :name, :instrument, :tuning, :capo, :midi_channel, :created_at, :updated_at
end
