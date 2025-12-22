require "nokogiri"

class MusicxmlIndexer
  def self.index_file(xml_path)
    doc = Nokogiri::XML(File.read(xml_path))
    doc.remove_namespaces!

    tempo_bpm = doc.at_xpath("//sound[@tempo]")&.[]("tempo")&.to_f&.round
    parts = doc.xpath("//part")

    tracks = []
    chords_count = 0

    parts.each_with_index do |part, idx|
      measures = part.xpath("./measure")
      notes_total = 0
      measures.each do |m|
        m.xpath(".//note").each do |n|
          notes_total += 1
          chords_count += 1 if n.at_xpath("./chord")
        end
      end

      tracks << {
        "index" => idx,
        "name"  => part.at_xpath("./part-name")&.text&.presence || "Part #{idx+1}",
        "measures_count" => measures.size,
        "notes_count"    => notes_total
      }
    end

    {
      "tempo_bpm"    => tempo_bpm,
      "tracks"       => tracks,
      "chords_count" => chords_count
    }
  end
end
