class CourseFramework < ApplicationRecord
  belongs_to :course
  belongs_to :skill_framework

  validates :skill_framework_id, uniqueness: { scope: :course_id }
end
