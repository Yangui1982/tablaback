class TrackSerializer < ActiveModel::Serializer
  attributes :id, :name, :instrument, :tuning, :capo,
             :midi_channel, :midi_program, # program sera nil si colonne absente, ok
             :created_at, :updated_at
  def midi_program
    if object.respond_to?(:has_attribute?) && object.has_attribute?("program") && object["program"].present?
      object["program"].to_i
    else
      INSTRUMENT_TO_GM.fetch(object.instrument.to_s.downcase, 24)
    end
  end

  # Mapping minimal → étends-le selon tes besoins
  INSTRUMENT_TO_GM = {
    "guitar"          => 24, # Acoustic Guitar (nylon)
    "acoustic guitar" => 24,
    "electric guitar" => 29, # Overdriven Guitar
    "piano"           => 0,  # Acoustic Grand Piano
    "bass"            => 32, # Acoustic Bass
    "violin"          => 40
  }.freeze
end
