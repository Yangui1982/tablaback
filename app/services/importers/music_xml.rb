module Importers
  class MusicXml
    class ParseError < StandardError; end

    def self.call(io)
      xml = io.read
      raise ParseError, "Empty file" if xml.blank?

      # TODO: utilise ton service MusicXmlToJson (MVP) ici quand prêt
      { doc: { "title" => "Imported MusicXML (stub)", "tracks" => [] } }
    end
  end
end
