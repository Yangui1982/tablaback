class ScoreSerializer < ActiveModel::Serializer
  attributes :id, :title, :status, :imported_format,
             :key_sig, :time_sig, :tempo,
             :doc,
             :source_url,
             :normalized_mxl_url,
             :midi_url,
             :preview_pdf_url,
             :preview_png_urls,
             :created_at, :updated_at, :tracks_count

  has_many :tracks, serializer: TrackSerializer

  def source_url
    return unless object.source_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.source_file, only_path: false)
  end

  def normalized_mxl_url
    return unless object.normalized_mxl.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.normalized_mxl, only_path: false)
  end

  def midi_url
    return unless object.export_midi_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.export_midi_file, only_path: false)
  end

  # Tu ne veux plus PDF/PNG : tu peux laisser, ou supprimer plus tard.
  # Ici on laisse pour compat, mais si attachments supprimés, ça renverra nil/[].
  def preview_pdf_url
    return unless object.preview_pdf.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.preview_pdf, only_path: false)
  end

  def preview_png_urls
    return [] unless object.preview_pngs.attached?
    object.preview_pngs.map { |p| Rails.application.routes.url_helpers.rails_blob_url(p, only_path: false) }
  end

  # --- DOC (avec filtrage piste + normalisation) -----------------------------

  def doc
    return nil unless include_doc?

    d = object.doc
    return d unless d.is_a?(Hash)

    # 1) Filtre par piste si track_index fourni
    ti = instance_options[:track_index]
    if ti.present?
      ti = ti.to_i
      tracks = Array(d["tracks"])
      kept = tracks.find { |t| t.is_a?(Hash) && t["index"].to_i == ti }
      d = d.merge("tracks" => kept ? [kept] : [])
    end

    # 2) Normalisation légère : éviter fret/string "0" si présents
    normalize_doc!(d)

    d
  end

  private

  def include_doc?
    return true unless instance_options.key?(:with_doc)
    instance_options[:with_doc] == true
  end

  # Modifie le hash en place : supprime string/fret si incohérents
  def normalize_doc!(d)
    tracks = Array(d["tracks"])
    tracks.each do |t|
      next unless t.is_a?(Hash)
      notes = Array(t["notes"])
      next if notes.empty?

      notes.each do |n|
        next unless n.is_a?(Hash)

        # si fret=0 mais pas de string -> fret n’a pas de sens
        if n.key?("fret") && n["fret"].to_i == 0 && (n["string"].nil? || n["string"].to_i <= 0)
          n["fret"] = nil
        end

        # string <= 0 => nil
        if n.key?("string") && n["string"].to_i <= 0
          n["string"] = nil
        end
      end
    end
  end
end
