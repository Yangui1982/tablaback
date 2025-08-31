module Importers
  class Registry
    def self.for(format)
      case format
      when :guitarpro then Importers::GuitarPro
      when :musicxml  then Importers::MusicXML
      else Importers::Unsupported
      end
    end
  end
end
