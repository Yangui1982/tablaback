require "timeout"

class ImportScoreJob < ApplicationJob
  queue_as :imports
  # retry_on StandardError, wait: :polynomially_longer, attempts: 8
  discard_on ActiveRecord::RecordNotFound

  def perform(score_id)
    filename = nil
    byte_size = nil
    imported_format = nil

    Rails.logger.info("[ImportScoreJob] start score_id=#{score_id}")

    score = Score.find(score_id)

    if score.status.to_s == "ready"
      Rails.logger.info("[ImportScoreJob] skip score_id=#{score_id} status=ready")
      return
    end

    raise "source_file_missing" unless score.source_file.attached?

    filename = score.source_file.blob&.filename&.to_s
    byte_size = score.source_file.blob&.byte_size
    imported_format = score.imported_format.presence || infer_format_from_filename(filename)
    raise "unsupported_format" if imported_format == "unknown"

    Rails.logger.info("[ImportScoreJob] meta score_id=#{score_id} format=#{imported_format} filename=#{filename} size=#{byte_size}")

    payload =
      begin
        Timeout.timeout(parse_timeout_seconds) { parse_file(score, imported_format) }
      rescue Timeout::Error
        raise "import_timeout"
      end

    doc = normalize_doc(payload, imported_format)

    score.update!(
      doc: doc,
      status: :ready,
      import_error: nil
    )

    Rails.logger.info("[ImportScoreJob] done score_id=#{score_id} -> ready")
  rescue => e
    Rails.logger.error("[ImportScoreJob] FAILED score_id=#{score_id}: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { score_id: score_id, imported_format: imported_format, filename: filename, byte_size: byte_size }) if defined?(Sentry)
    begin
      score.update!(status: :failed, import_error: e.message) if score
    rescue StandardError
    end
    raise e
  end

  private

  def parse_timeout_seconds
    Integer(ENV.fetch("IMPORT_PARSE_TIMEOUT", 30))
  rescue ArgumentError
    30
  end

  def normalize_doc(payload, default_format)
    raw = payload.fetch(:doc)
    doc = raw.is_a?(Hash) ? raw.deep_stringify_keys : { "data" => raw }
    doc["format"] ||= payload[:format].presence || default_format
    doc
  end

  def parse_file(score, imported_format)
    score.source_file.blob.open do |io|
      case imported_format
      when "guitarpro"
        Importers::GuitarPro.call(io, filename: score.source_file.filename&.to_s)
      when "musicxml"
        Importers::MusicXml.call(io)
      else
        raise "unsupported_format"
      end
    end
  end

  def infer_format_from_filename(name)
    ext = File.extname(name.to_s).downcase
    return "guitarpro" if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return "musicxml"  if %w[.xml .musicxml .mxl].include?(ext)
    "unknown"
  end
end
