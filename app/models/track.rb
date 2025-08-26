class Track < ApplicationRecord
  belongs_to :score, counter_cache: true

  validates :name,
    presence: true,
    length: { maximum: 100 }

  validates :instrument,
    length: { maximum: 100 },
    allow_blank: true

  validates :tuning,
    length: { maximum: 50 },
    allow_blank: true

  validates :capo,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 25 },
    allow_nil: true

  validates :name,
    uniqueness: {
      scope: :score_id,
      message: "est déjà utilisé dans cette partition"
    }

  validates :midi_channel,
    allow_nil: true,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 16
    }

  validates :midi_channel,
    uniqueness: {
      scope: :score_id,
      message: "est déjà utilisé dans cette partition"
    },
    allow_nil: true
end
