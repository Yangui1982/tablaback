module Importers
  class GuitarPro
    VALID_EXTS = %w[.gp3 .gp4 .gp5 .gpx .gp].freeze
    class ParseError < StandardError; end

    def self.call(io, filename: nil) = new(io, filename).call

    def initialize(io, filename)
      @io = io
      @filename = filename
    end

    def call
      data = @io.read&.dup&.force_encoding("BINARY")
      raise "empty_file" if data.nil? || data.empty?

      if @filename.present?
        ext = File.extname(@filename).downcase
        raise "wrong_extension_for_guitarpro" unless VALID_EXTS.include?(ext)
      end
      # Sanity check très léger : beaucoup de GP3 commencent par "FICHIER GUITAR PRO"
      version_guess =
        if data[0,64]&.include?("FICHIER GUITAR PRO")
          3
        else
          "unknown"
        end

      {
        doc: {
          "format"  => "guitarpro",
          "version" => version_guess,
          "size"    => data.bytesize
        }
      }
    end
  end
end
