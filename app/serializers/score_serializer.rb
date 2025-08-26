class ScoreSerializer < ActiveModel::Serializer
  attributes :id, :title, :status, :imported_format,
             :key_sig, :time_sig, :tempo, :doc, :source_url,
             :created_at, :updated_at

  has_many :tracks

  def source_url
    return unless object.source_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.source_file, only_path: false)
  end
end
