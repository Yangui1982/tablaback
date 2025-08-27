class Project < ApplicationRecord
  belongs_to :user
  has_many :scores, dependent: :destroy
  validates :title, presence: true, length: { maximum: 200 }
  validates :title, uniqueness: { scope: :user_id }
end
