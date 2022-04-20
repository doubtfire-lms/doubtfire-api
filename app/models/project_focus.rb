class ProjectFocus < ApplicationRecord
  belongs_to :project, optional: false
  belongs_to :focus, optional: false

  validates :grade_achieved, numericality: { greater_than_or_equal_to: GradeHelper::PASS_VALUE, less_than_or_equal_to: GradeHelper::HD_VALUE }, allow_nil: true

  validate :unit_must_be_same, on: :create

  def award_grade grade, task, user
    self.grade_achieved = grade
    self.save

    FocusGradeAwardComment.create!(
      task: task,
      user: user,
      comment: "Awarded grade #{grade} for focus #{self.focus.title}",
      content_type: :text,
      recipient: self.project.student,
      grade_achieved: grade
    )
  end

  def unit_must_be_same
    errors.add(:project, 'and focus belong to different units') unless project.unit == focus.unit
  end

end
