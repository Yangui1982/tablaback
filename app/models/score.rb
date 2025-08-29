class Score < ApplicationRecord
  include ScoreDefaults
  before_validation :ensure_doc!

  belongs_to :project
  has_many :tracks, dependent: :destroy

  has_one_attached :source_file
  has_one_attached :export_midi_file
  has_one_attached :export_musicxml_file

  ALLOWED_XML = %w[
    application/xml text/xml
    application/vnd.recordare.musicxml+xml
    application/vnd.recordare.musicxml
  ].freeze
  ALLOWED_GP_OCTET = %w[application/octet-stream].freeze
  ALLOWED_MIDI = [
    /\Aaudio\/(midi|mid)\z/,
    /\Aaudio\/x-midi\z/
  ].freeze

  validates :source_file,
            content_type: (ALLOWED_XML + ALLOWED_GP_OCTET),
            size: { less_than: 20.megabytes },
            if: -> { source_file.attached? }

  validate :source_file_extension_whitelist, if: -> { source_file.attached? }

  validates :export_midi_file,
            content_type: ALLOWED_MIDI,
            size: { less_than: 20.megabytes },
            if: -> { export_midi_file.attached? }

  validates :export_musicxml_file,
            content_type: ALLOWED_XML,
            size: { less_than: 20.megabytes },
            if: -> { export_musicxml_file.attached? }

  enum status: { draft: 0, processing: 1, ready: 2, failed: 3 }, _default: :draft

  validates :title, presence: true, length: { maximum: 200 }, uniqueness: { scope: :project_id }
  validates :doc, presence: true
  validates :tempo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :exports_require_source

  after_destroy_commit :purge_attachments

  private

  def ensure_doc!
    self.doc = default_doc(title) if doc.blank?
  end

  def source_file_extension_whitelist
    allowed_exts = %w[.gp3 .gp4 .gp5 .gpx .gp .xml .musicxml .mxl]
    ext = File.extname(source_file.filename.to_s).downcase
    unless allowed_exts.include?(ext)
      errors.add(:source_file, "extension non supportée. Autorisées: #{allowed_exts.join(' ')}")
    end
  end

  def exports_require_source
    if (export_midi_file.attached? || export_musicxml_file.attached?) && !source_file.attached?
      errors.add(:base, "Les exports nécessitent un fichier source")
    end
  end

  def purge_attachments
    source_file.purge_later if source_file.attached?
    export_midi_file.purge_later if export_midi_file.attached?
    export_musicxml_file.purge_later if export_musicxml_file.attached?
  end
end
