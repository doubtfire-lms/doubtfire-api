class FocusGradeAwardComment < TaskComment
  validates :grade_achieved, inclusion: { in: GradeHelper::FULL_RANGE, message: '%{value} is not in the correct range' }
  validates :previous_grade, numericality: { only_integer: true, greater_than_or_equal_to: GradeHelper::FULL_RANGE.min, less_than_or_equal_to: GradeHelper::FULL_RANGE.max }, allow_nil: true
  validates :focus, presence: true

  before_create do
    self.content_type = :focus_award
  end
end
