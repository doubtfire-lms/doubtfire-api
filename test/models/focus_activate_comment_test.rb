require "test_helper"

class FocusActivateCommentTest < ActiveSupport::TestCase

  def test_focus_activate_comment_needs_focus
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusActivateComment.create(
      task: task,
      user: user,
      focus: nil,
      comment: "Started focusing on ??",
      recipient: task.project.student
    )

    refute comment.valid?
  end

  def test_focus_activate_comment_create
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)
    task = u.active_projects.first.task_for_task_definition(u.task_definitions.first)
    user = u.main_convenor_user

    comment = FocusActivateComment.create(
      task: task,
      user: user,
      focus: nil,
      comment: "Started focusing on ??",
      recipient: task.project.student
    )

    refute comment.valid?
  end
end
