class Score < ApplicationRecord
  belongs_to :project
  has_many :tracks, dependent: :destroy

  has_one_attached :source_file
  has_one_attached :export_midi_file
  has_one_attached :export_musicxml_file

  validates :source_file,
            content_type: ['application/xml', 'text/xml', 'application/octet-stream'],
            size: { less_than: 20.megabytes },
            if: -> { source_file.attached? }

  enum status: { draft: 'draft', processing: 'processing', ready: 'ready', failed: 'failed' }, _default: 'draft'

  validates :title, presence: true
  validates :doc, presence: true
  validates :tempo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
