require 'test_helper'

class TaskDeadlineNotificationJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @now = Time.zone.local(2026, 9, 7, 9)
    @unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 1,
      allow_flexible_dates: true,
      start_date: @now - 2.weeks,
      end_date: @now + 2.months
    )
    @definition = @unit.task_definitions.first
    @student = FactoryBot.create(:user, :student)
    @project = FactoryBot.create(
      :project,
      unit: @unit,
      user: @student,
      enrolled: true,
      target_grade: @definition.target_grade
    )
    @task = FactoryBot.create(
      :task,
      project: @project,
      task_definition: @definition,
      target_start_date: @now.to_date,
      target_due_date: (@now + 10.days).to_date
    )
  end

  def test_creates_each_start_transition_once
    travel_to(@now) do
      2.times { Notification.refresh_task_deadline_notifications! }
    end

    assert_equal ['task_start_now'], @student.received_notifications.where(task: @task).pluck(:kind)
  end

  def test_creates_due_soon_and_overdue_transitions
    travel_to(@now + 5.days) do
      Notification.refresh_task_deadline_notifications!
    end
    travel_to(@now + 11.days) do
      Notification.refresh_task_deadline_notifications!
    end

    notifications = @student.received_notifications.order(:created_at)
    assert_equal %w[task_due_soon task_overdue], notifications.pluck(:kind)
    assert_not_nil notifications.first.read_at
    assert_nil notifications.last.read_at
    assert_equal 'warning', NotificationGroupBuilder.new([notifications.first]).groups.first[:severity]
    assert_equal 'critical', NotificationGroupBuilder.new([notifications.last]).groups.first[:severity]
  end

  def test_changed_due_date_allows_another_overdue_transition
    @task.update!(target_due_date: (@now - 1.day).to_date)
    travel_to(@now) { Notification.refresh_task_deadline_notifications! }

    @task.update!(target_due_date: (@now + 10.days).to_date)
    travel_to(@now + 11.days) { Notification.refresh_task_deadline_notifications! }

    overdue = @student.received_notifications.where(kind: 'task_overdue').order(:created_at)
    assert_equal 2, overdue.count
    assert_not_nil overdue.first.read_at
    assert_nil overdue.last.read_at
  end

  def test_submitted_task_resolves_a_pending_deadline_notification
    travel_to(@now) { Notification.refresh_task_deadline_notifications! }
    @task.update!(task_status: TaskStatus.ready_for_feedback)

    travel_to(@now + 1.hour) do
      Notification.refresh_task_deadline_notifications!
    end

    assert_not_nil @student.received_notifications.first.read_at
  end

  def test_digest_groups_deadline_notifications_into_sections_and_emails_them_only_once
    due_soon_definition = FactoryBot.create(
      :task_definition,
      unit: @unit,
      target_grade: @definition.target_grade
    )
    overdue_definition = FactoryBot.create(
      :task_definition,
      unit: @unit,
      target_grade: @definition.target_grade
    )
    due_soon_task = FactoryBot.create(
      :task,
      project: @project,
      task_definition: due_soon_definition,
      target_start_date: (@now - 1.week).to_date,
      target_due_date: (@now + 5.days).to_date
    )
    overdue_task = FactoryBot.create(
      :task,
      project: @project,
      task_definition: overdue_definition,
      target_start_date: (@now - 2.weeks).to_date,
      target_due_date: (@now - 1.day).to_date
    )

    travel_to(@now) do
      Notification.refresh_task_deadline_notifications!
      Notification.create_for_portfolio(@project, success: true)
      settings = NotificationSetting.for(@student)

      assert_emails 1 do
        SendNotificationDigestJob.new.perform(settings.id)
      end
      text = ActionMailer::Base.deliveries.last.text_part.body.to_s
      html = ActionMailer::Base.deliveries.last.html_part.body.to_s
      NotificationsMailer::TASK_DEADLINE_SECTIONS.map(&:last).each do |heading|
        assert_includes text, heading
        assert_includes html, heading
      end
      [@task, due_soon_task, overdue_task].each do |task|
        due_text = "Due #{task.local_due_date.day.ordinalize} #{task.local_due_date.strftime('%B')}"
        assert_includes text, due_text
        assert_includes html, due_text
      end
      assert_equal 1, text.scan('7th September 2026 at 09:00').count
      assert_includes html, 'justify-content:space-between'
      start_heading = text.index('Tasks ready to start')
      due_heading = text.index('Tasks due within five days')
      overdue_heading = text.index('Tasks past due')
      assert_operator start_heading, :<, text.index("- #{@definition.abbreviation} -")
      assert_operator text.index("- #{@definition.abbreviation} -"), :<, due_heading
      assert_operator due_heading, :<, text.index("- #{due_soon_task.task_definition.abbreviation} -")
      assert_operator text.index("- #{due_soon_task.task_definition.abbreviation} -"), :<, overdue_heading
      assert_operator overdue_heading, :<, text.index("- #{overdue_task.task_definition.abbreviation} -")
      updates_heading = text.index('Task updates')
      assert_operator text.index("- #{overdue_task.task_definition.abbreviation} -"), :<, updates_heading
      assert_operator updates_heading, :<, text.index('- Portfolio')
      assert_includes html, '<hr '
      assert_no_emails do
        SendNotificationDigestJob.new.perform(settings.id)
      end
    end

    assert_not_nil @student.received_notifications.find_by!(task: @task).email_sent_at
  end

  def test_student_can_disable_a_deadline_notification_type
    settings = NotificationSetting.for(@student)
    settings.update!(channels: settings.channels.merge('task_start_now' => []))

    travel_to(@now) { Notification.refresh_task_deadline_notifications! }

    assert_not @student.received_notifications.exists?(task: @task, kind: 'task_start_now')
  end

  def test_digest_does_not_send_a_reminder_for_an_old_due_date
    @task.update!(target_due_date: (@now - 1.day).to_date)
    travel_to(@now) { Notification.refresh_task_deadline_notifications! }
    notification = @student.received_notifications.find_by!(task: @task, kind: 'task_overdue')
    @task.update!(target_due_date: (@now + 10.days).to_date)

    travel_to(@now + 1.hour) do
      assert_no_emails do
        SendNotificationDigestJob.new.perform(NotificationSetting.for(@student).id)
      end
    end

    assert_not_nil notification.reload.email_processed_at
    assert_nil notification.email_sent_at
  end

  def test_creates_the_task_record_when_the_assigned_task_has_not_been_opened
    @task.destroy!
    @definition.update!(start_date: @now.to_date, target_date: (@now + 10.days).to_date)

    travel_to(@now) { Notification.refresh_task_deadline_notifications! }

    task = @project.tasks.find_by!(task_definition: @definition)
    assert @student.received_notifications.exists?(task: task, kind: 'task_start_now')
  end
end
