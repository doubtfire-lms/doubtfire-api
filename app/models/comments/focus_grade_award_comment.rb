class FocusGradeAwardComment < TaskComment
  validates :grade_achieved, inclusion: { in: GradeHelper::FULL_RANGE, message: '%{value} is not in the correct range' }
end
