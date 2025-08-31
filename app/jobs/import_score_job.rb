# app/jobs/import_score_job.rb
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

    # ---- Idempotence / Concurrence
    should_skip = false
    ActiveRecord::Base.transaction do
      score.lock!

      if score.status.to_s.in?(%w[ready processing])
        should_skip = true
      else
        raise "source_file_missing" unless score.source_file.attached?

        filename  = score.source_file.blob&.filename&.to_s
        byte_size = score.source_file.blob&.byte_size
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

    # ---- Parse avec timeout
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    payload =
      begin
        Timeout.timeout(parse_timeout_seconds) { parse_file(score, imported_format) }
      rescue Timeout::Error
        raise "import_timeout"
      end
    parse_duration_s = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0).round(3)

    # ---- Normalisation du doc pivot (on reste en processing ici)
    doc = normalize_doc(payload, imported_format)
    score.update!(doc: doc, import_error: nil)
    score.update!(doc: doc, import_error: nil, tempo: doc["tempo_bpm"].to_i)
    score.update!(duration_ticks: score.compute_duration_ticks)
    score.sync_tracks_from_doc! rescue nil

    # ---- Génère et attache le MIDI (mix complet) SEULEMENT s'il y a des notes
    if any_note_in_doc?(score.doc)
      midi_bytes = (payload[:midi_bytes] || payload["midi_bytes"]) # compat future
      data = midi_bytes.presence || MidiRenderService.new(doc: score.doc, title: score.title).call
      score.attach_midi!(data, filename: "#{(score.title.presence || 'score').parameterize}.mid")
    else
      Rails.logger.info("[ImportScoreJob] no notes in doc -> skipping MIDI render")
    end

    # ---- OK → ready
    score.update!(status: :ready)

    Rails.logger.info("[ImportScoreJob] done score_id=#{score_id} -> ready parse_duration=#{parse_duration_s}s")
  rescue Importers::GuitarPro::ParseError, Importers::MusicXml::ParseError => e
    handle_failure(score, e, imported_format, filename, byte_size, parse_duration_s)
    raise e if Rails.env.test?
  rescue => e
    handle_failure(score, e, imported_format, filename, byte_size, parse_duration_s)
    raise e # on laisse remonter en test
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

  def handle_failure(score, e, imported_format, filename, byte_size, parse_duration_s)
    Rails.logger.error("[ImportScoreJob] FAILED score_id=#{score&.id}: #{e.class}: #{e.message} format=#{imported_format} filename=#{filename} size=#{byte_size} parse_duration=#{parse_duration_s}")
    if defined?(Sentry) && Sentry.respond_to?(:with_scope)
      begin
        Sentry.with_scope do |scope|
          if scope.respond_to?(:set_tags)
            scope.set_tags(job: self.class.name, format: imported_format, filename: filename)
          end
          if scope.respond_to?(:set_extras)
            scope.set_extras(score_id: score&.id, byte_size: byte_size, parse_duration_s: parse_duration_s)
          end
          Sentry.capture_exception(e)
        end
      rescue NoMethodError
        # tolérance aux doubles pour les tests
      end
    end
    begin
      score.update!(status: :failed, import_error: e.message) if score
    rescue StandardError
      # on évite un second crash si l'update échoue
    end
  end

  def any_note_in_doc?(doc)
    Array(doc["tracks"]).any? { |t| Array(t["notes"]).any? { |n| n.is_a?(Hash) && n["duration"].to_i > 0 } }
  end
end
