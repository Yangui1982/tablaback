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

  def preview_pdf_url
    return unless object.preview_pdf.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.preview_pdf, only_path: false)
  end

  def preview_png_urls
    return [] unless object.preview_pngs.attached?
    object.preview_pngs.map { |p| Rails.application.routes.url_helpers.rails_blob_url(p, only_path: false) }
  end

  def doc
    return object.doc if include_doc?
    nil
  end

  private

  def include_doc?
    return true unless instance_options.key?(:with_doc)
    instance_options[:with_doc] == true
  end
end
