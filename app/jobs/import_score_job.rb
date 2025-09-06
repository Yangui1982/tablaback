require "timeout"
require "zip"
require "nokogiri"
require "fileutils"

class ImportScoreJob < ApplicationJob
  queue_as :imports
  retry_on(StandardError, wait: :polynomially_longer, attempts: 8) unless Rails.env.test?
  discard_on ActiveRecord::RecordNotFound

  # On accepte un correlation_id optionnel
  def perform(score_id, correlation_id: nil)
    cid              = correlation_id.presence || SecureRandom.hex(6)
    filename         = nil
    byte_size        = nil
    imported_format  = nil
    parse_duration_s = nil

    Rails.logger.info("[ImportScoreJob][cid=#{cid}] start score_id=#{score_id}")

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
      Rails.logger.info("[ImportScoreJob][cid=#{cid}] skip score_id=#{score_id} status=#{score.status}")
      return
    end

    Rails.logger.info("[ImportScoreJob][cid=#{cid}] meta score_id=#{score_id} format=#{imported_format} filename=#{filename} size=#{byte_size}")

    # ---- Canonisation & assets (sous timeout)
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(parse_timeout_seconds) do
      canonize_and_generate_assets!(score, imported_format, cid: cid)
    end
    parse_duration_s = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0).round(3)

    # ---- OK → ready
    score.update!(status: :ready)
    Rails.logger.info("[ImportScoreJob][cid=#{cid}] done score_id=#{score_id} -> ready parse_duration=#{parse_duration_s}s")

  rescue => e
    handle_failure(score, e, imported_format, filename, byte_size, parse_duration_s, cid: cid)
    raise e if Rails.env.test?
  end

  private

  # ========= Étape principale : canoniser + générer assets + indexer =========
  def canonize_and_generate_assets!(score, imported_format, cid:)
    Dir.mktmpdir("score_#{score.id}_") do |dir|
      cli = MusescoreCli.new
      score.update!(imported_format: imported_format) if imported_format.present?

      # 1) Sauver la source sur disque
      src_path = download_to(score.source_file, File.join(dir, "source"))
      mxl_path = File.join(dir, "normalized.mxl")        # <-- canon (.mxl)
      xml_path = File.join(dir, "normalized.musicxml")   # <-- temp pour index

      # 2) Produire le canon .mxl
      if src_path =~ /\.mxl\z/i
        FileUtils.cp(src_path, mxl_path)
      else
        cli.to_musicxml(src_path, mxl_path) # out=.mxl → MusicXML compressé
      end

      # 3) Générer les assets depuis le .mxl
      mid_path    = File.join(dir, "mix.mid")
      pdf_path    = File.join(dir, "score.pdf")
      png_pattern = File.join(dir, "page.png") # MuseScore sort page-1.png…

      cli.to_midi(mxl_path, mid_path)
      cli.to_pdf(mxl_path,  pdf_path)
      cli.to_pngs(mxl_path, png_pattern)

      # 4) Attacher le canon .mxl
      attach_one(score.normalized_mxl, mxl_path, safe_name(score, ".mxl"), "application/vnd.recordare.musicxml")

      # 5) Indexer : extraire un .musicxml temporaire → MusicxmlIndexer
      extract_mxl_to_xml(mxl_path, xml_path)
      index = MusicxmlIndexer.index_file(xml_path) # => Hash
      score.doc = index
      score.update!(tempo: index["tempo_bpm"].to_i) if index["tempo_bpm"].present?

      # 6) Métriques & sync
      score.update!(duration_ticks: score.compute_duration_ticks)
      begin
        score.sync_tracks_from_doc!(correlation_id: cid)
      rescue => e
        Rails.logger.warn("[ImportScoreJob][cid=#{cid}] sync_tracks_from_doc! failed: #{e.class}: #{e.message}")
      end

      # 7) MIDI : purge si pas de notes, sinon attacher si absent
      if any_note_in_index?(index)
        attach_one(score.export_midi_file, mid_path, safe_name(score, ".mid"), "audio/midi") unless score.export_midi_file.attached?
      else
        Rails.logger.info("[ImportScoreJob][cid=#{cid}] no notes detected in index -> dropping MIDI")
        score.export_midi_file.purge_later if score.export_midi_file.attached?
      end

      # 8) Previews (PDF + PNGs)
      attach_one(score.preview_pdf, pdf_path, safe_name(score, ".pdf"), "application/pdf")
      Dir[File.join(dir, "page*.png")].sort.each_with_index do |png, i|
        score.preview_pngs.attach(
          io: File.open(png, "rb"),
          filename: "#{score.title.to_s.parameterize}-p#{i + 1}.png",
          content_type: "image/png"
        )
      end

      score.save!
    end
  end

  # ---- Helpers --------------------------------------------------------------

  def parse_timeout_seconds
    Integer(ENV.fetch("IMPORT_PARSE_TIMEOUT", 60))
  rescue ArgumentError
    60
  end

  def infer_format_from_filename(name)
    ext = File.extname(name.to_s).downcase
    return "guitarpro" if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return "mxl" if ext == ".mxl"
    return "musicxml"  if %w[.xml .musicxml].include?(ext)
    "unknown"
  end

  def any_note_in_index?(index)
    Array(index["tracks"]).any? { |t| t.is_a?(Hash) && t["notes_count"].to_i > 0 }
  end

  def download_to(att, target_base)
    raise "source_file_missing" unless att&.attached?
    ext  = File.extname(att.filename.to_s)
    path = "#{target_base}#{ext}"
    File.open(path, "wb") { |f| f.write(att.download) }
    path
  end

  def attach_one(att_obj, path, filename, content_type)
    File.open(path, "rb") do |f|
      att_obj.attach(io: f, filename:, content_type:)
    end
  end

  def safe_name(score, ext)
    base = (score.title.presence || "score").to_s.parameterize
    "#{base}#{ext}"
  end

  # .mxl (zip) -> .musicxml (XML clair) sur disque
  def extract_mxl_to_xml(mxl_path, xml_target_path)
    Zip::File.open(mxl_path) do |zip|
      container = zip.glob("META-INF/container.xml").first
      raise "no_container_in_mxl" unless container

      container_doc = Nokogiri::XML(container.get_input_stream.read)
      container_doc.remove_namespaces!
      rootfile = container_doc.at_xpath("//rootfile")
      raise "no_rootfile_in_mxl" unless rootfile

      main_path = rootfile["full-path"]
      raise "no_full_path_in_container" unless main_path

      entry = zip.find_entry(main_path) || zip.glob(main_path).first
      raise "main_xml_not_found_in_mxl" unless entry

      xml_bytes = entry.get_input_stream.read
      File.binwrite(xml_target_path, xml_bytes)
    end
  end

  def handle_failure(score, e, imported_format, filename, byte_size, parse_duration_s, cid:)
    Rails.logger.error("[ImportScoreJob][cid=#{cid}] FAILED score_id=#{score&.id}: #{e.class}: #{e.message} format=#{imported_format} filename=#{filename} size=#{byte_size} parse_duration=#{parse_duration_s}")
    if defined?(Sentry) && Sentry.respond_to?(:with_scope)
      begin
        Sentry.with_scope do |scope|
          scope.set_tags(job: self.class.name, format: imported_format, filename: filename, cid: cid) if scope.respond_to?(:set_tags)
          scope.set_extras(score_id: score&.id, byte_size: byte_size, parse_duration_s: parse_duration_s) if scope.respond_to?(:set_extras)
          Sentry.capture_exception(e)
        end
      rescue NoMethodError
      end
    end
    begin
      score.update!(status: :failed, import_error: e.message) if score
    rescue StandardError
    end
  end
end
