class Track < ApplicationRecord
  belongs_to :score, counter_cache: true
  validates :name, presence: true
end
