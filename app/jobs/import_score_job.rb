require "timeout"

class ImportScoreJob < ApplicationJob
  queue_as :imports
  retry_on(StandardError, wait: :polynomially_longer, attempts: 8) unless Rails.env.test?
  discard_on ActiveRecord::RecordNotFound

  def perform(score_id)
    filename         = nil
    byte_size        = nil
    imported_format  = nil
    parse_duration_s = nil

    Rails.logger.info("[ImportScoreJob] start score_id=#{score_id}")

    score = Score.find(score_id)

    # ---- Idempotence / Concurrence : on verrouille la ligne, on saute si ready/processing,
    # et on marque 'processing' avant de parser.
    should_skip = false
    ActiveRecord::Base.transaction do
      score.lock!

      if score.status.to_s == "ready" || score.status.to_s == "processing"
        should_skip = true
      else
        # On capture quelques métadonnées (observabilité)
        filename  = score.source_file.blob&.filename&.to_s
        byte_size = score.source_file.blob&.byte_size

        # Échecs rapides
        raise "source_file_missing" unless score.source_file.attached?

        imported_format = score.imported_format.presence || infer_format_from_filename(filename)
        raise "unsupported_format" if imported_format == "unknown"

        score.update!(status: :processing, import_error: nil)
      end
    end
    if should_skip
      Rails.logger.info("[ImportScoreJob] skip score_id=#{score_id} status=#{score.status}")
      return
    end

    Rails.logger.info("[ImportScoreJob] meta score_id=#{score_id} format=#{imported_format} filename=#{filename} size=#{byte_size}")

    # ---- Timeout du parse
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    payload =
      begin
        Timeout.timeout(parse_timeout_seconds) { parse_file(score, imported_format) }
      rescue Timeout::Error
        raise "import_timeout"
      end
    parse_duration_s = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0).round(3)

    # Normalisation du doc
    doc = normalize_doc(payload, imported_format)

    score.update!(
      doc: doc,
      status: :ready,
      import_error: nil
    )

    Rails.logger.info("[ImportScoreJob] done score_id=#{score_id} -> ready parse_duration=#{parse_duration_s}s")
  rescue => e
    # Observabilité : logs + Sentry avec tags utiles
    Rails.logger.error("[ImportScoreJob] FAILED score_id=#{score_id}: #{e.class}: #{e.message} format=#{imported_format} filename=#{filename} size=#{byte_size} parse_duration=#{parse_duration_s}")
    if defined?(Sentry)
      Sentry.with_scope do |scope|
        scope.set_tags(job: self.class.name, format: imported_format, filename: filename)
        scope.set_extras(score_id: score_id, byte_size: byte_size, parse_duration_s: parse_duration_s)
        Sentry.capture_exception(e)
      end
    end

    begin
      score.update!(status: :failed, import_error: e.message) if score
    rescue StandardError
      # on évite un second crash si l'update échoue
    end

    # En test on veut que l'exception remonte (les specs `raise_error`),
    # en prod elle sera saisie par ActiveJob si retry_on est actif.
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
