class Score < ApplicationRecord
  include ScoreDefaults

  # --- Callbacks -------------------------------------------------------------
  before_validation :ensure_doc!
  before_save       :sync_tempo_from_doc

  # --- Associations ----------------------------------------------------------
  belongs_to :project
  has_many   :tracks, dependent: :destroy

  # Active Storage
  has_one_attached :source_file
  has_one_attached :export_midi_file      # mix complet du score (cache)
  has_one_attached :export_musicxml_file

  # --- Content types / validations ------------------------------------------
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

  # --- Domain validations ----------------------------------------------------
  enum status: { draft: 0, processing: 1, ready: 2, failed: 3 }, _default: :draft

  validates :title, presence: true, length: { maximum: 200 }, uniqueness: { scope: :project_id }
  validates :doc,   presence: true
  validates :tempo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # MusicXML doit provenir d'une source_file ; le MIDI peut être généré depuis `doc`
  validate :exports_require_source

  after_destroy_commit :purge_attachments

  # --- MIDI cache helpers ----------------------------------------------------
  # Calcule le checksum courant du doc (utilisé pour invalider/valider le cache MIDI)
  def doc_checksum_now
    Digest::SHA256.hexdigest(doc.to_json)
  end

  # Le cache MIDI est-il à jour ?
  def midi_up_to_date?
    export_midi_file.attached? && doc_checksum.present? && doc_checksum == doc_checksum_now
  end

  # Attache/maj le .mid (mix complet) + met à jour le checksum
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
    seen = []
    Array(doc["tracks"]).each_with_index do |t, i|
      name    = t["name"].presence || "Track #{i+1}"
      chan    = t["channel"].to_i
      prog    = t["program"].to_i

      tr = tracks.where(name: name).first_or_initialize
      tr.midi_channel = chan if tr.respond_to?(:midi_channel=)
      tr.midi_program = prog if tr.respond_to?(:midi_program=)
      tr.instrument ||= "Imported" # si tu veux un label par défaut
      tr.save! if tr.changed?
      seen << tr.id
    end
  end

  private

  # Remplit un doc par défaut si vide (score vide valide : tracks: [])
  def ensure_doc!
    self.doc = default_doc(title) if doc.blank?
  end

  # Synchronise la colonne tempo (entier) avec doc["tempo_bpm"] pour faciliter tri/filtre API
  def sync_tempo_from_doc
    bpm = doc.is_a?(Hash) ? doc["tempo_bpm"] : nil
    self.tempo = bpm.to_i if bpm.present?
  end

  # Whitelist d’extensions pour la source (GP/MusicXML)
  def source_file_extension_whitelist
    allowed_exts = %w[.gp3 .gp4 .gp5 .gpx .gp .xml .musicxml .mxl]
    ext = File.extname(source_file.filename.to_s).downcase
    unless allowed_exts.include?(ext)
      errors.add(:source_file, "extension non supportée. Autorisées: #{allowed_exts.join(' ')}")
    end
  end

  # Le MIDI peut venir de `doc` (pas besoin de source_file) ; MusicXML reste contraint
  def exports_require_source
    if export_musicxml_file.attached? && !source_file.attached?
      errors.add(:base, "L'export MusicXML nécessite un fichier source")
    end
  end

  # Nettoyage storage après destruction
  def purge_attachments
    source_file.purge_later        if source_file.attached?
    export_midi_file.purge_later   if export_midi_file.attached?
    export_musicxml_file.purge_later if export_musicxml_file.attached?
  end
end
