class FocusReflectionComment < TaskComment
  QUESTION_RANGE = 0..5

  validates :task_shows_focus, inclusion: { in: QUESTION_RANGE, message: '%{value} is not in the correct range' }
  validates :focus_understanding, inclusion: { in: QUESTION_RANGE, message: '%{value} is not in the correct range' }
end
