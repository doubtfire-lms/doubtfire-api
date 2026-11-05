class SkillEvidence < ApplicationRecord
  belongs_to :task
  belongs_to :skill_level

  validates :submission_key, :submitted_at, presence: true
  validates :skill_level_id, uniqueness: { scope: [:task_id, :submission_key] }

  scope :current, -> { where(superseded_at: nil, archived_at: nil) }
  scope :endorsed, -> { where.not(endorsed_at: nil) }
end
