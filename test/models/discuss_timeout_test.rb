require 'test_helper'

class DiscussTimeoutTest < ActiveSupport::TestCase
  def test_discussion_deadline_uses_breaks_for_the_students_campus
    teaching_period = FactoryBot.create(
      :teaching_period,
      start_date: Time.zone.parse('2026-06-01 00:00:00'),
      end_date: Time.zone.parse('2026-09-30 23:59:59'),
      active_until: Time.zone.parse('2026-10-31 23:59:59')
    )
    campus = FactoryBot.create(:campus)
    other_campus = FactoryBot.create(:campus)
    teaching_period.add_break(Time.zone.parse('2026-07-13 00:00:00'), 7, [other_campus.id])
    teaching_period.add_break(Time.zone.parse('2026-07-27 00:00:00'), 7, [campus.id])
    unit = FactoryBot.create(:unit, teaching_period: teaching_period)
    task = unit.active_projects.first.task_for_task_definition(unit.task_definitions.first)
    task.project.update!(campus: campus)
    task.update!(moved_to_discuss_at: Time.zone.parse('2026-07-06 12:00:00'))

    assert_equal Time.zone.parse('2026-07-20 12:00:00'), task.discuss_timeout_expiry_at(14)
  end

  def test_teaching_period_break_pauses_warning_and_expiry
    travel_to Time.zone.parse('2026-07-23 12:00:00') do
      teaching_period = FactoryBot.create(
        :teaching_period,
        start_date: Time.zone.parse('2026-06-01 00:00:00'),
        end_date: Time.zone.parse('2026-09-30 23:59:59'),
        active_until: Time.zone.parse('2026-10-31 23:59:59')
      )
      teaching_period.add_break(Time.zone.parse('2026-07-13 00:00:00'), 7)
      unit = FactoryBot.create(
        :unit,
        teaching_period: teaching_period,
        discuss_timeout_enabled: true,
        discuss_timeout_warning_days: 7,
        discuss_timeout_expire_days: 14,
        send_notifications: false
      )
      task = unit.active_projects.first.task_for_task_definition(unit.task_definitions.first)
      task.update!(task_status: TaskStatus.discuss)
      task.update!(moved_to_discuss_at: Time.zone.parse('2026-07-06 12:00:00'))

      assert_equal 10, task.discuss_timeout_elapsed_days
      assert_equal Time.zone.parse('2026-07-27 12:00:00'), task.discuss_timeout_expiry_at
      assert_equal 1, unit.notify_discuss_timeouts!
      assert_equal TaskStatus.discuss, task.reload.task_status
      assert task.notified_discuss_warning_at.present?

      travel 4.days

      assert_equal 14, task.discuss_timeout_elapsed_days
      assert_equal 1, unit.notify_discuss_timeouts!
      assert_equal TaskStatus.fix_and_resubmit, task.reload.task_status
    end
  end

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
