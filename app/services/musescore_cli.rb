require "shellwords"

class MusescoreCli
  class Error < StandardError; end

  def initialize(bin: ENV["MUSESCORE_BIN"])
    @bin = bin.presence || detect_binary!
  end

  def to_musicxml(input_path, output_path)
    run! "#{@bin} #{Shellwords.escape(input_path)} -o #{Shellwords.escape(output_path)}"
  end

  def to_midi(input_path, output_path)
    run! "#{@bin} #{Shellwords.escape(input_path)} -o #{Shellwords.escape(output_path)}"
  end

  def to_pdf(input_path, output_path)
    run! "#{@bin} #{Shellwords.escape(input_path)} -o #{Shellwords.escape(output_path)}"
  end

  def to_pngs(input_path, output_pattern)
    run! "#{@bin} #{Shellwords.escape(input_path)} -o #{Shellwords.escape(output_pattern)}"
  end

  private

  def run!(cmd)
    out = `#{cmd} 2>&1`
    raise Error, out unless $?.success?
    out
  end

  def detect_binary!
    candidates = [
      `which mscore 2>/dev/null`.strip,
      `which mscore3 2>/dev/null`.strip,
      `which musescore3 2>/dev/null`.strip,
      "/mnt/c/Program Files/MuseScore 3/bin/MuseScore3.exe"
    ].compact_blank
    bin = candidates.find { |p| p.present? && File.exist?(p) }
    raise Error, "MuseScore CLI introuvable; définis MUSESCORE_BIN" unless bin
    bin
  end
end
