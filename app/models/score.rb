class Score < ApplicationRecord
  include ScoreDefaults

  # --- Callbacks -------------------------------------------------------------
  before_validation :ensure_doc!
  before_save       :sync_tempo_from_doc
  after_destroy_commit :purge_attachments

  # --- Associations ----------------------------------------------------------
  belongs_to :project
  has_many   :tracks, dependent: :destroy

  # --- Active Storage --------------------------------------------------------
  has_one_attached  :source_file
  has_one_attached  :export_midi_file
  has_one_attached  :normalized_mxl      # <- canon (MusicXML compressé)
  has_one_attached  :preview_pdf
  has_many_attached :preview_pngs

  # --- Content types / validations ------------------------------------------
  # MXL (compressé) : souvent sniffé comme application/zip
  ALLOWED_MXL = [
    "application/vnd.recordare.musicxml",
    %r{\Aapplication/(zip|x-zip-compressed)\z}
  ].freeze

  # Types XML « clairs »
  ALLOWED_XML = %w[
    application/xml
    text/xml
    application/vnd.recordare.musicxml+xml
    application/vnd.recordare.musicxml
  ].freeze

  # Types réellement observés pour la **source** (XML, MXL=zippé, GP binaire).
  # ⚠️ Ne mettre que des strings reconnus par Marcel OU des regex.
  ALLOWED_SOURCE_TYPES = (
    ALLOWED_XML + [
      %r{\Aapplication/(zip|x-zip-compressed)\z},
      "application/octet-stream"
    ]
  ).freeze

  ALLOWED_MIDI = [
    /\Aaudio\/(midi|mid)\z/,
    /\Aaudio\/x-midi\z/
  ].freeze

  VALID_PDF = %w[application/pdf].freeze
  VALID_PNG = %w[image/png].freeze

  validates :source_file,
            content_type: ALLOWED_SOURCE_TYPES,
            size: { less_than: 20.megabytes },
            if: -> { source_file.attached? }

  validate :source_file_extension_whitelist, if: -> { source_file.attached? }

  validates :export_midi_file,
            content_type: ALLOWED_MIDI,
            size: { less_than: 20.megabytes },
            if: -> { export_midi_file.attached? }

  validates :normalized_mxl,
            content_type: ALLOWED_MXL,
            size: { less_than: 20.megabytes },
            if: -> { normalized_mxl.attached? }

  validates :preview_pdf,
            content_type: VALID_PDF,
            size: { less_than: 20.megabytes },
            if: -> { preview_pdf.attached? }

  validate :preview_pngs_types_and_size

  # --- Domain validations ----------------------------------------------------
  enum status: { draft: 0, processing: 1, ready: 2, failed: 3 }, _default: :draft

  validates :title, presence: true, length: { maximum: 200 }, uniqueness: { scope: :project_id }
  validates :doc,   presence: true
  validates :tempo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # --- Helpers validations ---------------------------------------------------
  def preview_pngs_types_and_size
    return unless preview_pngs.attached?

    preview_pngs.each do |p|
      errors.add(:preview_pngs, "chaque image doit faire < 20 MB") if p.blob.byte_size > 20.megabytes
      errors.add(:preview_pngs, "doit être des PNG") unless VALID_PNG.include?(p.blob.content_type)
    end
  end

  # --- MIDI cache helpers ----------------------------------------------------
  def doc_checksum_now
    Digest::SHA256.hexdigest(doc.to_json)
  end

  def midi_up_to_date?
    export_midi_file.attached? && doc_checksum.present? && doc_checksum == doc_checksum_now
  end

  def attach_midi!(data, filename: nil)
    self.doc_checksum = doc_checksum_now
    export_midi_file.attach(
      io: StringIO.new(data),
      filename: (filename.presence || "#{(title.presence || 'score').parameterize}.mid"),
      content_type: "audio/midi"
    )
    save!
  end

  def compute_duration_ticks
    Array(doc["tracks"]).flat_map { |t|
      Array(t["notes"]).map { |n| n["start"].to_i + n["duration"].to_i }
    }.max.to_i
  end

  def sync_tracks_from_doc!
    Array(doc["tracks"]).each_with_index do |t, i|
      name = t["name"].presence || "Track #{i + 1}"
      chan = t["channel"].to_i
      prog = t["program"].to_i

      tr = tracks.where(name: name).first_or_initialize
      safe_chan = (1..16).cover?(chan) ? chan : nil
      tr.midi_channel = safe_chan if tr.respond_to?(:midi_channel=)
      tr.midi_program = prog       if tr.respond_to?(:midi_program=)
      tr.instrument   ||= "Imported"
      tr.save! if tr.changed?
    end
  end

  # --- Public URLs helpers ---------------------------------------------------
  def normalized_mxl_url
    return unless normalized_mxl.attached?
    Rails.application.routes.url_helpers.url_for(normalized_mxl)
  end

  def midi_url
    return unless export_midi_file.attached?
    Rails.application.routes.url_helpers.url_for(export_midi_file)
  end

  def preview_pdf_url
    return unless preview_pdf.attached?
    Rails.application.routes.url_helpers.url_for(preview_pdf)
  end

  def preview_png_urls
    return [] unless preview_pngs.attached?
    preview_pngs.map { |p| Rails.application.routes.url_helpers.url_for(p) }
  end

  private

  def ensure_doc!
    self.doc = default_doc(title) if doc.blank?
  end

  def sync_tempo_from_doc
    bpm = doc.is_a?(Hash) ? doc["tempo_bpm"] : nil
    self.tempo = bpm.to_i if bpm.present?
  end

  # Whitelist d’extensions pour la source (GP/MusicXML)
  def source_file_extension_whitelist
    allowed_exts = %w[.gp3 .gp4 .gp5 .gpx .gp .xml .musicxml .mxl]
    ext = File.extname(source_file.filename.to_s).downcase
    errors.add(:source_file, "extension non supportée. Autorisées: #{allowed_exts.join(' ')}") unless allowed_exts.include?(ext)
  end

  # Nettoyage storage après destruction
  def purge_attachments
    source_file.purge_later      if source_file.attached?
    export_midi_file.purge_later if export_midi_file.attached?
    normalized_mxl.purge_later   if normalized_mxl.attached?
    preview_pdf.purge_later      if preview_pdf.attached?
    preview_pngs.each(&:purge_later) if preview_pngs.attached?
  end
end
