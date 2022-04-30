class ProjectFocus < ApplicationRecord
  belongs_to :project, optional: false
  belongs_to :focus, optional: false

  validates :grade_achieved, numericality: { greater_than_or_equal_to: GradeHelper::PASS_VALUE, less_than_or_equal_to: GradeHelper::HD_VALUE }, allow_nil: true

  validate :unit_must_be_same, on: :create

  def award_grade grade, move_on, task, user
    old_grade = self.grade_achieved

    self.grade_achieved = grade
    self.current &= ! move_on
    self.save

    if old_grade && old_grade > grade
      message = "Reduced grade from #{GradeHelper::short_grade_for(old_grade)} to #{GradeHelper::short_grade_for(grade)} for focus #{self.focus.title}"
    else
      message = "Awarded #{GradeHelper::short_grade_for(grade)} for focus #{self.focus.title}."
    end

    FocusGradeAwardComment.create!(
      task: task,
      user: user,
      focus: self.focus,
      comment: message,
      recipient: self.project.student,
      grade_achieved: grade,
      previous_grade: old_grade
    )
  end

  def unit_must_be_same
    errors.add(:project, 'and focus belong to different units') unless project.unit == focus.unit
  end

  def make_current user, task, current = true
    return if self.current == current

    self.current = current
    self.save

    if current
      message = "Started focusing on #{focus.title}"
    else
      message = "Stopped focusing on #{focus.title}"
    end

    FocusActivateComment.create!(
      task: task,
      user: user,
      focus: self.focus,
      comment: message,
      recipient: self.project.student
    )
  end

  def focus_comments
    project.comments.where(focus: focus)
  end

end
