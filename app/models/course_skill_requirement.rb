class CourseSkillRequirement < ApplicationRecord
  belongs_to :course
  belongs_to :skill
  belongs_to :skill_level

  validates :skill_id, uniqueness: { scope: :course_id }
  validate :level_matches_skill
  validate :framework_selected_by_course

  private

  def level_matches_skill
    errors.add(:skill_level, 'must belong to the selected skill') if skill_level && skill && skill_level.skill_id != skill_id
  end

  def framework_selected_by_course
    return unless course && skill
    return if course.course_frameworks.any? { |entry| entry.skill_framework_id == skill.skill_framework_id }

    errors.add(:skill, 'must belong to a framework selected by this course')
  end
end
