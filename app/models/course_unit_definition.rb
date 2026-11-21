class CourseUnitDefinition < ApplicationRecord
  belongs_to :course
  belongs_to :unit_definition

  validates :unit_definition_id, uniqueness: { scope: :course_id }
end
