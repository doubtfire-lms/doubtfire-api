class SkillLevel < ApplicationRecord
  belongs_to :skill
  has_many :skill_evidences, dependent: :restrict_with_exception

  validates :name, :rank, presence: true
  validates :rank, uniqueness: { scope: :skill_id }, numericality: { only_integer: true, greater_than: 0 }
end
