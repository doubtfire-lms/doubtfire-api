require 'test_helper'

class DiscussTimeoutTest < ActiveSupport::TestCase
  def test_expiry_forces_fix_and_resubmit_without_feedback_and_adds_comments_in_order
    unit = FactoryBot.create(
      :unit,
      discuss_timeout_enabled: true,
      discuss_timeout_warning_days: 7,
      discuss_timeout_expire_days: 14,
      send_notifications: false
    )
    project = unit.active_projects.first
    task = project.task_for_task_definition(unit.task_definitions.first)
    task.update!(task_status: TaskStatus.discuss)
    task.update!(
      moved_to_discuss_at: 15.days.ago,
      notified_discuss_warning_at: nil,
      notified_discuss_expiry_at: nil
    )

    assert_equal 1, unit.notify_discuss_timeouts!

    task.reload
    assert_equal TaskStatus.fix_and_resubmit, task.task_status

    status_comment, expiry_comment = task.comments.order(:created_at, :id).last(2)
    assert_equal 'status', status_comment.content_type
    assert_equal TaskStatus.fix_and_resubmit, status_comment.task_status
    assert_equal DiscussTimeoutComment.expired, expiry_comment.content_type
    assert_includes expiry_comment.comment, 'because it was not discussed by the deadline'
  end
end
