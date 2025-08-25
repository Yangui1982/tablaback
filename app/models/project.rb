class Project < ApplicationRecord
  belongs_to :user
  has_many :scores, dependent: :destroy
  validates :title, presence: true
end
