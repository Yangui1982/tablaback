class Score < ApplicationRecord
  belongs_to :project
  has_many :tracks, dependent: :destroy

  enum status: { draft: 'draft', processing: 'processing', ready: 'ready', failed: 'failed' }, _default: 'draft'

  validates :title, presence: true
  validates :doc, presence: true
  validates :tempo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
