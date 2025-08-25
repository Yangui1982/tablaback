class TrackSerializer < ActiveModel::Serializer
  attributes :id, :name, :instrument, :tuning, :capo, :channel
end
