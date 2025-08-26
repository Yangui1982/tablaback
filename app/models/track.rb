class Track < ApplicationRecord
  belongs_to :score, counter_cache: true
  validates :name, presence: true, length: { maximum: 200 }, uniqueness: { scope: :score_id }
  validates :midi_channel,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 16 },
            uniqueness: { scope: :score_id },
            allow_nil: true
end
