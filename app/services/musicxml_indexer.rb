require "nokogiri"

class MusicxmlIndexer
  PPQ = 480

  def self.index_file(xml_path)
    xml = File.read(xml_path)
    doc = Nokogiri::XML(xml)
    doc.remove_namespaces!

    # Tempo (MuseScore met souvent <sound tempo="...">)
    tempo_bpm =
      doc.at_xpath("//sound[@tempo]")&.[]("tempo")&.to_f ||
      doc.at_xpath("//per-minute")&.text.to_f
    tempo_bpm = tempo_bpm.to_f
    tempo_bpm = 120.0 if tempo_bpm <= 0

    # Title (souvent <work-title>, sinon <movement-title>)
    title =
      doc.at_xpath("//work/work-title")&.text.to_s.strip.presence ||
      doc.at_xpath("//movement-title")&.text.to_s.strip.presence

    # Divisions = unité MusicXML (durations exprimées en "divisions" par noire)
    divisions = doc.at_xpath("//attributes/divisions")&.text.to_i
    divisions = 1 if divisions <= 0

    # Signature rythmique (première rencontrée)
    beats = doc.at_xpath("//time/beats")&.text.to_i
    beat_type = doc.at_xpath("//time/beat-type")&.text.to_i
    beats = 4 if beats <= 0
    beat_type = 4 if beat_type <= 0

    parts = doc.xpath("//part")

    tracks = []
    chords_count = 0

    parts.each_with_index do |part, idx|
      measures = part.xpath("./measure")
      notes_total = 0
      tick = 0
      notes = []

      # Nom de partie : via part-list (fiable), fallback "Part n"
      part_id = part["id"].to_s
      part_name =
        doc.at_xpath(%(//part-list/score-part[@id="#{part_id}"]/part-name))&.text.to_s.strip.presence ||
        "Part #{idx + 1}"

      measures.each do |m|
        m.xpath("./note").each do |n|
          is_chord = n.at_xpath("./chord").present?
          is_rest  = n.at_xpath("./rest").present?

          # durée MusicXML (en "divisions")
          dur_xml = n.at_xpath("./duration")&.text.to_i
          dur_xml = 0 if dur_xml < 0

          # conversion vers ticks
          dur_ticks = ((dur_xml * PPQ) / divisions.to_f).round
          # fallback si la durée manque (rare mais possible selon export)
          dur_ticks = (PPQ / 4) if dur_ticks <= 0

          # compteurs (comme avant)
          notes_total += 1
          chords_count += 1 if is_chord

          # pitch midi (si ce n’est pas un rest)
          pitch = nil
          unless is_rest
            pnode = n.at_xpath("./pitch")
            if pnode
              step  = pnode.at_xpath("./step")&.text
              alter = pnode.at_xpath("./alter")&.text.to_i
              oct   = pnode.at_xpath("./octave")&.text.to_i
              pitch = midi_from(step, alter, oct) if step && oct
            end
          end

          # Technique tablature (si présent dans MusicXML)
          string_txt = n.at_xpath("./notations/technical/string")&.text
          fret_txt   = n.at_xpath("./notations/technical/fret")&.text

          string = string_txt.to_i if string_txt.present?
          fret   = fret_txt.to_i   if fret_txt.present?

          string = nil if string && string <= 0
          fret   = nil if fret && fret < 0

          # On stocke uniquement les notes (pas les rests)
          if pitch
            notes << {
              "start"    => tick,
              "duration" => dur_ticks,
              "pitch"    => pitch,
              "string"   => string, # peut être nil
              "fret"     => fret    # peut être nil
            }
          end

          # Avance le temps seulement si ce n’est pas une note d’accord (simultanée)
          tick += dur_ticks unless is_chord
        end
      end

      tracks << {
        "index" => idx,
        "name"  => part_name,
        "measures_count" => measures.size,
        "notes_count"    => notes_total,
        "notes"          => notes
      }
    end

    {
      "schema_version" => 2,
      "title"          => title,
      "ppq"            => PPQ,
      "tempo_bpm"      => tempo_bpm.round,
      "time_signature" => [beats, beat_type],
      "tracks"         => tracks,
      "chords_count"   => chords_count
    }
  end

  def self.midi_from(step, alter, octave)
    base = { "C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11 }[step.to_s]
    return nil unless base
    ((octave.to_i + 1) * 12) + base + alter.to_i
  end
end
