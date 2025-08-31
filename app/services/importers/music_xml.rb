require "nokogiri"

module Importers
  class MusicXml
    class ParseError < StandardError; end

    PPQ = 480

    def self.call(io) = new(io).call

    def initialize(io)
      @io = io
    end

    def call
      xml = @io.respond_to?(:read) ? @io.read : @io.to_s
      raise ParseError, "empty_file" if xml.blank?

      doc = Nokogiri::XML(xml) { |cfg| cfg.strict.noblanks }
      doc.remove_namespaces!

      # ----- Métadonnées haut niveau -----------------------------------------
      title = (
        doc.at_xpath("//work/work-title")&.text ||
        doc.at_xpath("//movement-title")&.text ||
        "Imported"
      ).to_s

      # Time signature (première occurrence)
      beats     = doc.at_xpath("(//attributes/time/beats)[1]")&.text&.to_i
      beat_type = doc.at_xpath("(//attributes/time/beat-type)[1]")&.text&.to_i
      time_sig  = [(beats && beats > 0 ? beats : 4), (beat_type && beat_type > 0 ? beat_type : 4)]

      # Tempo (priorité aux directions de mesure)
      tempo_bpm = nil
      if (dir_tempo = doc.at_xpath("(//direction//sound[@tempo])[1]")&.[]("tempo"))
        tempo_bpm = dir_tempo.to_f
      elsif (g_sound = doc.at_xpath("(//sound[@tempo])[1]")&.[]("tempo"))
        tempo_bpm = g_sound.to_f
      else
        per_min = doc.at_xpath("(//direction//metronome//per-minute)[1]")&.text&.to_f
        tempo_bpm = per_min if per_min && per_min.positive?
      end
      tempo_bpm = (tempo_bpm && tempo_bpm.positive?) ? tempo_bpm.round : 120

      # ----- score-part → métas (nom, midi channel/program) -------------------
      part_meta = {}
      doc.xpath("//part-list/score-part").each do |sp|
        pid   = sp["id"].to_s
        pname = sp.at_xpath("./part-name")&.text&.strip
        pname = pid if pname.blank?

        midi_program = sp.at_xpath(".//midi-instrument/midi-program")&.text&.to_i
        midi_channel = sp.at_xpath(".//midi-instrument/midi-channel")&.text&.to_i

        part_meta[pid] = {
          name:    pname,
          program: midi_program, # peut être nil
          channel: midi_channel  # peut être nil
        }
      end

      # ----- Parcours des parties (ordre réel des événements) -----------------
      tracks = []

      # Divisions par défaut : première rencontrée dans le document
      global_div = doc.at_xpath("(//attributes/divisions)[1]")&.text&.to_i
      global_div = (global_div && global_div > 0) ? global_div : 1

      doc.xpath("//part").each_with_index do |part, idx|
        pid   = part["id"].to_s
        meta  = part_meta[pid] || {}
        name  = meta[:name].presence || "Track #{idx + 1}"
        prog  = (meta[:program].presence || 25).to_i  # par défaut : guitare (GM steel)
        chan  = (meta[:channel].presence || 0).to_i

        # curseur temporel en divisions musicxml (pas en ticks)
        cur_div_pos = 0
        cur_div     = global_div
        last_note_start_div = 0 # pour gérer <chord/>
        notes = []

        # On parcourt les éléments **dans l'ordre** de chaque mesure
        part.xpath("./measure").each do |measure|
          # mise à jour éventuelle des divisions dans la mesure
          if (local_div = measure.at_xpath("./attributes/divisions")&.text&.to_i)
            cur_div = local_div if local_div > 0
          end

          # tempo local éventuel (on ne change pas la valeur globale stockée,
          # mais tu peux l’ajouter plus tard dans score["tempo"]["map"])
          # kept for future: measure.at_xpath(".//direction//sound[@tempo]")

          measure.elements.each do |el|
            case el.name
            when "attributes"
              # rien d'autre à faire ici pour le MVP (divisions déjà gérées)
            when "backup"
              dur = el.at_xpath("./duration")&.text&.to_i
              cur_div_pos -= dur if dur && dur > 0
              cur_div_pos = [cur_div_pos, 0].max
            when "forward"
              dur = el.at_xpath("./duration")&.text&.to_i
              cur_div_pos += dur if dur && dur > 0
            when "direction"
              # on pourrait lire tempo local ici et pousser dans une tempo map
            when "note"
              is_rest  = el.at_xpath("./rest").present?
              dur_div  = el.at_xpath("./duration")&.text&.to_i
              has_chord = el.at_xpath("./chord").present?

              # Grace notes n'ont souvent pas de duration → on les ignore pour le MVP
              if is_rest
                # un silence fait simplement avancer le curseur
                cur_div_pos += dur_div if dur_div && dur_div > 0 && !has_chord
                next
              end

              # pitch
              step   = el.at_xpath("./pitch/step")&.text
              octave = el.at_xpath("./pitch/octave")&.text&.to_i
              alter  = el.at_xpath("./pitch/alter")&.text&.to_i || 0

              # si pas de vraie durée ou pas de pitch → skip
              next unless dur_div && dur_div > 0 && step && !octave.nil?

              start_div = has_chord ? last_note_start_div : cur_div_pos

              start_ticks = (start_div * (PPQ.to_f / cur_div)).round
              dur_ticks   = (dur_div   * (PPQ.to_f / cur_div)).round
              dur_ticks = 1 if dur_ticks <= 0

              pitch_midi = to_midi(step, alter, octave)
              next unless pitch_midi

              notes << {
                "start"    => start_ticks,
                "duration" => dur_ticks,
                "pitch"    => pitch_midi,
                "velocity" => 90
              }

              last_note_start_div = start_div
              # on n’avance le curseur **que** si ce n’est pas un accord
              cur_div_pos += dur_div unless has_chord
            else
              # autres tags ignorés pour le MVP
            end
          end
        end

        tracks << {
          "name"    => name,
          "channel" => chan,
          "program" => prog,
          "notes"   => notes
        }
      end

      {
        doc: {
          "schema_version" => 1,
          "title"          => title,
          "ppq"            => PPQ,
          "tempo_bpm"      => tempo_bpm,
          "time_signature" => time_sig,
          "tempo"          => { "bpm" => tempo_bpm, "map" => [] },
          "measures"       => [],
          "tracks"         => tracks
        }
      }
    rescue Nokogiri::XML::SyntaxError => e
      raise ParseError, "invalid_xml: #{e.message}"
    end

    private

    # step: "C".."B", alter: -1/0/1, octave: 0..9
    # MIDI: C4 = 60 → (octave + 1) * 12 + semitone
    def to_midi(step, alter, octave)
      base = { "C"=>0, "D"=>2, "E"=>4, "F"=>5, "G"=>7, "A"=>9, "B"=>11 }[step]
      return nil unless base
      (12 * (octave.to_i + 1)) + base + alter.to_i
    end
  end
end
