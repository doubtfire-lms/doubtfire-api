require "test_helper"

class FocusGradeAwardCommentTest < ActiveSupport::TestCase

  def test_focus_grade_award_comment_needs_focus
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusGradeAwardComment.create(
      task: task,
      user: user,
      focus: nil,
      grade_achieved: GradeHelper::PASS_VALUE,
      previous_grade: nil,
      comment: "Award focus",
      recipient: task.project.student
    )

    refute comment.valid?
  end

  def test_focus_grade_award_comment_needs_grade
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusGradeAwardComment.create(
      task: task,
      user: user,
      focus: u.focuses.first,
      grade_achieved: nil,
      previous_grade: nil,
      comment: "Award focus",
      recipient: task.project.student
    )

    refute comment.valid?
  end

  def test_focus_grade_award_comment_create
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusGradeAwardComment.create(
      task: task,
      user: user,
      focus: u.focuses.first,
      grade_achieved: GradeHelper::PASS_VALUE,
      previous_grade: nil,
      comment: "Award focus",
      recipient: task.project.student
    )

    assert comment.valid?
  end

  def test_focus_grade_award_comment_grade_range
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusGradeAwardComment.create(
      task: task,
      user: user,
      focus: u.focuses.first,
      grade_achieved: GradeHelper::FAIL_VALUE - 1,
      previous_grade: nil,
      comment: "Award focus",
      recipient: task.project.student
    )

    refute comment.valid?

    comment.grade_achieved = GradeHelper::HD_VALUE + 1
    refute comment.valid?

    comment.grade_achieved = GradeHelper::PASS_VALUE
    assert comment.valid?

    comment.previous_grade = GradeHelper::FAIL_VALUE - 1
    refute comment.valid?

    comment.previous_grade = GradeHelper::HD_VALUE + 1
    refute comment.valid?

    comment.previous_grade = GradeHelper::HD_VALUE
    assert comment.valid?
  end
end
