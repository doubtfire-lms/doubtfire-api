class TaskDefinitionSkillMapping < ApplicationRecord
  belongs_to :task_definition
  belongs_to :skill
  belongs_to :skill_level

  validates :skill_id, uniqueness: { scope: :task_definition_id }
  validate :level_matches_skill

  private

  def level_matches_skill
    errors.add(:skill_level, 'must belong to the selected skill') if skill_level && skill && skill_level.skill_id != skill_id
  end
end
