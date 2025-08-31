class ScoreSerializer < ActiveModel::Serializer
  attributes :id, :title, :status, :imported_format,
             :key_sig, :time_sig, :tempo,
             :doc,            # ⚠️ inclus par défaut (compat), voir include_doc?
             :source_url,     # lien vers fichier source (si attaché)
             :midi_url,       # lien vers export .mid (si attaché)
             :created_at, :updated_at, :tracks_count

  has_many :tracks, serializer: TrackSerializer

  # -- URLs -------------------------------------------------------------------
  def source_url
    return unless object.source_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.source_file, only_path: false)
  end

  def midi_url
    return unless object.export_midi_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.export_midi_file, only_path: false)
  end

  # -- doc conditionnel -------------------------------------------------------
  # Par défaut, on garde doc (pour compat). Tu peux l'exclure en passant with_doc: false
  def doc
    return object.doc if include_doc?
    nil
  end

  private

  def include_doc?
    # inclus si l'option n'est pas fournie, ou explicitement true
    return true unless instance_options.key?(:with_doc)
    instance_options[:with_doc] == true
  end
end
