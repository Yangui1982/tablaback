class Track < ApplicationRecord
  belongs_to :score
  validates :name, presence: true
end
