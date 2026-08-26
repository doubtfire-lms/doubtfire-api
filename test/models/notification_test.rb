require 'test_helper'

class NotificationTest < ActiveSupport::TestCase
  def setup
    super
    @unit = FactoryBot.create(:unit, task_count: 1)
    @project = @unit.active_projects.first
    @task = @project.task_for_task_definition(@unit.task_definitions.first)
    @student = @project.student
    @tutor = @project.tutor_for(@task.task_definition)
  end

  def test_tutor_feedback_creates_an_unread_student_notification
    comment = @task.add_text_comment(@tutor, 'Please revise this section')

    notification = Notification.find_by(task_comment: comment, recipient: @student)

    assert_not_nil notification
    assert_equal 'new_task_comment', notification.kind
    assert_equal @task, notification.task
    assert_nil notification.read_at
  end

  def test_student_feedback_notifies_staff_but_student_status_does_not
    comment = @task.add_text_comment(@student, 'Could you clarify this feedback?')
    @task.add_status_comment(@student, TaskStatus.ready_for_feedback)

    assert Notification.exists?(task_comment: comment, recipient: @tutor, kind: 'new_task_comment')
    assert_not Notification.exists?(recipient: @tutor, kind: 'task_status_changed')
  end

  def test_staff_group_feedback_fans_out_to_each_students_corresponding_task
    unit = FactoryBot.create(
      :unit,
      task_count: 1,
      student_count: 2,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      group_sets: 1,
      group_tasks: [{ idx: 0, gs: 0 }],
      groups: [{ gs: 0, students: 2 }]
    )
    group = unit.groups.first
    tasks = group.projects.map { |project| project.task_for_task_definition(unit.task_definitions.first) }
    comment = tasks.first.add_text_comment(tasks.first.project.tutor_for(tasks.first.task_definition), 'Group feedback')
    group_member_status = tasks.first.add_status_comment(
      tasks.second.project.student,
      TaskStatus.ready_for_feedback
    )

    notifications = Notification.where(task_comment: comment).order(:recipient_id)

    assert_equal group.projects.map(&:student).sort_by(&:id), notifications.map(&:recipient).sort_by(&:id)
    assert_equal tasks.map(&:id).sort, notifications.map(&:task_id).sort
    assert_not Notification.exists?(task_comment: group_member_status)
  end

  def test_only_latest_staff_status_notification_remains_unread
    first_comment = @task.add_status_comment(@tutor, TaskStatus.fix_and_resubmit)
    second_comment = @task.add_status_comment(@tutor, TaskStatus.complete)

    first_notification = Notification.find_by!(task_comment: first_comment, recipient: @student)
    second_notification = Notification.find_by!(task_comment: second_comment, recipient: @student)

    assert_not_nil first_notification.read_at
    assert_nil second_notification.read_at
    assert_equal TaskStatus.complete, second_notification.task_status
    assert_equal 1, Notification.where(recipient: @student, task: @task, kind: 'task_status_changed').unread.count
  end

  def test_group_builder_merges_mixed_task_activity
    3.times { |number| @task.add_text_comment(@tutor, "Feedback #{number}") }
    @task.add_status_comment(@tutor, TaskStatus.fix_and_resubmit)

    groups = NotificationGroupBuilder.new(Notification.where(recipient: @student).unread).groups

    assert_equal 1, groups.count
    assert_equal 3, groups.first[:counts]['new_task_comment']
    assert_equal :fix_and_resubmit, groups.first[:latest_status]
    assert_includes groups.first[:summary], '3 new comments'
    assert_includes groups.first[:summary], 'task status changed to Fix and Resubmit'
  end

  def test_discuss_expiry_supersedes_warning_without_hiding_feedback
    @task.add_text_comment(@tutor, 'Please review this before your discussion')
    warning = @task.add_discuss_timeout_comment(
      @tutor,
      DiscussTimeoutComment.warning,
      'Your discussion deadline is approaching'
    )
    expiry = @task.add_discuss_timeout_comment(
      @tutor,
      DiscussTimeoutComment.expired,
      'Your discussion deadline has passed'
    )

    warning_notification = Notification.find_by!(task_comment: warning, recipient: @student)
    expiry_notification = Notification.find_by!(task_comment: expiry, recipient: @student)
    group = NotificationGroupBuilder.new(Notification.where(recipient: @student).unread).groups.first

    assert_not_nil warning_notification.read_at
    assert_nil expiry_notification.read_at
    assert_equal 'critical', group[:severity]
    assert_equal 1, group[:counts]['discuss_expired']
    assert_equal 1, group[:counts]['new_task_comment']
    assert_includes group[:summary], 'Discussion deadline missed'
  end

  def test_task_tutor_note_and_student_feedback_share_a_group_with_two_actions
    @task.add_text_comment(@student, 'Can you check this change?')
    unit_role = @unit.unit_role_for(@tutor)
    tutor_note = unit_role.add_tutor_note(@unit.main_convenor_user, 'Please follow up', @task.id)
    Notification.create_for_tutor_note(tutor_note, @tutor, 'moderation_note_added')

    group = NotificationGroupBuilder.new(Notification.where(recipient: @tutor).unread).groups.first

    assert_equal 1, group[:counts]['new_task_comment']
    assert_equal 1, group[:counts]['moderation_note_added']
    assert_equal [tutor_note.id], group[:tutor_note_ids]
    assert_equal [Notification.find_by!(tutor_note: tutor_note).id], group[:tutor_note_notification_ids]
    assert group.dig(:task, :staff_view)
    assert_equal @student.name, group.dig(:task, :student_name)
    assert_includes group[:detail], "1 moderation note from #{@unit.main_convenor_user.name}"
  end

  def test_duplicate_source_event_is_deduplicated_per_recipient
    comment = @task.add_text_comment(@tutor, 'Only notify once')
    attributes = {
      recipient: @student,
      unit: @unit,
      project: @project,
      task: @task,
      actor: @tutor,
      kind: 'new_task_comment',
      task_comment: comment,
      deduplication_key: 'same-event'
    }

    first = Notification.create_event(**attributes)
    second = Notification.create_event(**attributes)

    assert_equal first, second
    assert_equal 1, Notification.where(recipient: @student, deduplication_key: 'same-event').count
  end

  def test_overseer_failure_is_created_immediately_but_email_is_held_for_the_grace_period
    submission_history = FactoryBot.create(:submission_history, task: @task)
    assessment = FactoryBot.create(
      :overseer_assessment,
      task: @task,
      submission_history: submission_history,
      status: :pre_queued
    )
    assessment.add_assessment_comment('Automated tests failed')

    assessment.update!(status: :failed)

    grace_period = OverseerAssessment.student_notification_grace_period
    notification = Notification.find_by!(
      overseer_assessment: assessment,
      recipient: @student,
      kind: 'overseer_failed'
    )
    assert notification.email_ready?(at: Time.current + grace_period + 1.minute)
    assert_not notification.email_ready?(at: Time.current + grace_period - 1.minute)
  end

  def test_portfolio_result_uses_the_notification_ledger
    notification = Notification.create_for_portfolio(@project, success: true)
    group = NotificationGroupBuilder.new([notification]).groups.first

    assert_equal 'portfolio_ready', notification.kind
    assert_equal @project, notification.project
    assert_equal @student, notification.recipient
    assert_nil notification.task
    assert_nil notification.read_at
    assert_equal @project.id, group[:project_id]
    assert_equal 'Portfolio - Portfolio ready to review', group[:summary]
  end

  def test_a_new_portfolio_result_resolves_the_previous_one
    ready = Notification.create_for_portfolio(@project, success: true)
    @project.update!(updated_at: 1.second.from_now)

    failed = Notification.create_for_portfolio(@project, success: false)

    assert_not_nil ready.reload.read_at
    assert_nil failed.read_at
    assert_equal 'portfolio_failed', failed.kind
  end

  def test_retrying_the_same_portfolio_result_does_not_mark_it_read
    first = Notification.create_for_portfolio(@project, success: true)
    duplicate = Notification.create_for_portfolio(@project, success: true)

    assert_equal first, duplicate
    assert_nil first.reload.read_at
  end

  def test_destroying_a_source_removes_its_notification
    comment = @task.add_text_comment(@tutor, 'Temporary feedback')
    notification = Notification.find_by!(task_comment: comment, recipient: @student)

    comment.destroy!

    assert_not Notification.exists?(notification.id)
  end

  def test_groups_are_sorted_by_newest_activity
    older_unread_notification = FactoryBot.create(
      :notification,
      recipient: @student,
      unit: @unit,
      kind: 'discuss_expired',
      created_at: 2.hours.ago
    )
    newer_read_notification = FactoryBot.create(
      :notification,
      recipient: @student,
      unit: @unit,
      kind: 'new_task_comment',
      created_at: 1.hour.ago,
      read_at: Time.current
    )

    groups = NotificationGroupBuilder.new([older_unread_notification, newer_read_notification]).groups

    assert_equal newer_read_notification.id, groups.first[:notification_ids].first
    assert groups.first[:read]
  end

  def test_marking_task_read_processes_email_and_marking_source_unread_reopens_in_app_only
    comment = @task.add_text_comment(@tutor, 'Read me')
    notification = Notification.find_by!(task_comment: comment, recipient: @student)

    Notification.mark_task_read(@student, @task)
    notification.reload

    assert_not_nil notification.read_at
    assert_not_nil notification.email_processed_at

    Notification.reopen_from_comment(comment, @student)
    notification.reload

    assert_nil notification.read_at
    assert_not_nil notification.email_processed_at
  end
end
