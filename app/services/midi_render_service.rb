require "midilib/sequence"
require "midilib/consts"

class MidiRenderService
  def initialize(doc:, title: "Score", track_indexes: nil)
    @doc           = doc || {}
    @title         = title.to_s
    @track_indexes = track_indexes
  end

  def call
    seq = MIDI::Sequence.new

    ppq       = (@doc["ppq"] || 480).to_i
    tempo_bpm = (@doc["tempo_bpm"] || 120).to_i.clamp(10, 400)
    num, den  = Array(@doc["time_signature"] || [4, 4])
    num       = num.to_i.positive? ? num.to_i : 4
    den       = normalize_denominator(den)

    seq.ppqn = ppq

    # Meta track
    meta = MIDI::Track.new(seq)
    seq.tracks << meta
    meta.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(tempo_bpm))
    meta.events << MIDI::TimeSig.new(num, den[:exp], 24, 8) # nn, dd(exp)
    meta.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, @title)

    # Sélection des pistes
    tracks = Array(@doc["tracks"])
    tracks = tracks.each_with_index.select { |_, i| Array(@track_indexes).include?(i) }.map(&:first) if @track_indexes

    raise ArgumentError, "empty_score" unless any_note?(tracks)

    tracks.each do |t|
      trk = MIDI::Track.new(seq)
      seq.tracks << trk

      channel = (t["channel"] || 0).to_i.clamp(0, 15)
      program = (t["program"] || 0).to_i.clamp(0, 127)
      name    = t["name"].to_s

      trk.events << MIDI::MetaEvent.new(MIDI::META_INSTRUMENT, name) if name.present?
      trk.events << MIDI::ProgramChange.new(channel, program, 0)

      current = 0
      Array(t["notes"])
        .map { |n| sanitize_note(n) }
        .compact
        .sort_by { |n| n[:start] }
        .each do |n|
          start, duration, pitch, vel = n.values_at(:start, :duration, :pitch, :velocity)

          delta = [start - current, 0].max
          trk.events << MIDI::NoteOn.new(channel, pitch, vel, delta)
          trk.events << MIDI::NoteOff.new(channel, pitch, 0, duration)
          current = start + duration
        end

      # trk.events << MIDI::MetaEvent.new(MIDI::META_END_OF_TRACK)
    end

    io = StringIO.new
    seq.write(io)
    io.string
  end

  private

  # Ensure denominator is a power of two; return both value and exponent for TimeSig
  def normalize_denominator(den)
    val = den.to_i
    pow2 = [1, 2, 4, 8, 16, 32, 64].find { |p| p == val } || 4
    { val: pow2, exp: Math.log2(pow2).to_i }
  end

  def sanitize_note(n)
    start    = n["start"].to_i
    duration = n["duration"].to_i
    pitch    = n["pitch"].to_i.clamp(0, 127)
    vel      = n["velocity"].to_i.clamp(1, 127)

    return nil if duration <= 0
    { start: [start, 0].max, duration:, pitch:, velocity: vel }
  end

  def any_note?(tracks)
    tracks.any? { |t| Array(t["notes"]).any? { |n| n.is_a?(Hash) && n["duration"].to_i > 0 } }
  end
end
