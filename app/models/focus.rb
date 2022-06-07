class Focus < ApplicationRecord
  belongs_to :unit, optional: false
  has_many :project_focuses, dependent: :destroy
  has_many :task_definition_required_focuses, dependent: :destroy
  has_many :task_comments, dependent: :destroy
  has_many :focus_criteria, dependent: :destroy

  validates :color, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }

  def set_grade_criteria(grade, criteria)
    if ! (GradeHelper::RANGE) === grade
      raise "Invalid grade"
    end

    fc = self.focus_criteria.where(grade: grade).first

    unless fc.nil?
      fc.update(criteria: criteria)
    else
      FocusCriteria.create(focus: self, grade: grade, criteria: criteria)
    end
  end
end
