require 'test_helper'

class NotificationJobsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def create_settings(**attributes)
    FactoryBot.create(:notification_setting, next_digest_at: 1.minute.ago, **attributes)
  end

  def test_digest_sends_only_the_events_enabled_on_the_email_channel
    settings = create_settings(channels: { 'new_task_comment' => ['in_app'] }.merge(
      NotificationSetting.default_channels.except('new_task_comment')
    ))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    NotificationUnitOverride.create!(
      user: settings.user,
      unit: unit,
      channels: { 'new_task_comment' => %w[in_app email] }
    )

    enabled = FactoryBot.create(:notification, recipient: settings.user, unit: unit, kind: 'new_task_comment')
    disabled = FactoryBot.create(:notification, recipient: settings.user, kind: 'new_task_comment')

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    digest_html = ActionMailer::Base.deliveries.last.html_part.body.to_s
    assert_equal 1, digest_html.scan('<style type="text/css">').count
    assert_includes digest_html, '/assets/images/logo.png'
    assert_includes digest_html, 'notification-box'
    assert_includes digest_html, 'Unsubscribe'
    assert_includes digest_html, unit.code
    assert_no_match(/<(?:table|tr|td)\b/, digest_html)
    assert_no_match(/\s(?:width|cellpadding|cellspacing|align|valign|nowrap)=/, digest_html)

    assert_not_nil enabled.reload.email_sent_at
    assert_not_nil disabled.reload.email_processed_at
    assert_nil disabled.email_sent_at
  end

  def test_digest_covers_every_unit_in_one_email
    settings = create_settings
    first = FactoryBot.create(:unit, with_students: false, task_count: 0)
    second = FactoryBot.create(:unit, with_students: false, task_count: 0)
    FactoryBot.create(:notification, recipient: settings.user, unit: first)
    FactoryBot.create(:notification, recipient: settings.user, unit: second)

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    digest_html = ActionMailer::Base.deliveries.last.html_part.body.to_s
    assert_includes digest_html, first.code
    assert_includes digest_html, second.code
  end

  def test_digest_renders_a_convenors_weekly_tutor_progress
    settings = create_settings
    settings.update!(channels: settings.channels.merge('weekly_summary' => %w[in_app email]))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    data = {
      audience: 'staff',
      week_start: 1.week.ago.iso8601,
      week_end: Time.current.iso8601,
      unit_comments: 10,
      unit_task_activity: 14,
      sent_comments: 6,
      received_comments: 2,
      student_task_activity: 9,
      has_students: true,
      is_convenor: true,
      assessed_tasks: 4,
      discussed_tasks: 3,
      awaiting_feedback: 2,
      oldest_task_days: 5,
      reverted_students: [],
      reverted_student_count: 0,
      tutorial_streams: [{
        name: 'On campus',
        unallocated_students: 1,
        tutors: [{
          tutor_name: 'Taylor Tutor',
          students: 18,
          total_assessments: 40,
          weekly_assessments: 7,
          total_comments: 62,
          weekly_comments: 8,
          awaiting_feedback: 3,
          oldest_task_days: 4,
          total_discussions: 12,
          weekly_discussions: 2
        }]
      }]
    }
    notification = Notification.create_weekly_summary(recipient: settings.user, unit: unit, data: data)

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.html_part.body.to_s, 'Tutor progress'
    assert_includes mail.html_part.body.to_s, 'Taylor Tutor'
    assert_includes mail.html_part.body.to_s, 'week / total'
    assert_match(%r{7\s*/\s*40}, mail.html_part.body.to_s)
    assert_includes mail.html_part.body.to_s, '1 student not allocated'
    assert_includes mail.text_part.body.to_s, 'assessments 7 this week / 40 total'
    assert_not_nil notification.reload.email_sent_at
  end

  def test_digest_renders_a_students_weekly_progress_and_focus_tasks
    settings = create_settings
    settings.update!(channels: settings.channels.merge('weekly_summary' => %w[in_app email]))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    data = {
      audience: 'student',
      week_start: 1.week.ago.iso8601,
      week_end: Time.current.iso8601,
      unit_comments: 10,
      unit_task_activity: 14,
      sent_comments: 2,
      received_comments: 3,
      task_activity: 5,
      student_task_activity: 4,
      tutor_allocated: true,
      did_revert_to_pass: false,
      portfolio_exists: false,
      top_tasks: [{
        abbreviation: 'P4',
        name: 'Loops',
        reason: 'soon',
        reason_label: 'Due soon',
        status: 'working_on_it'
      }]
    }
    Notification.create_weekly_summary(recipient: settings.user, unit: unit, data: data)

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.html_part.body.to_s, 'What to focus on next'
    assert_includes mail.html_part.body.to_s, 'Due soon'
    assert_includes mail.html_part.body.to_s, '/projects/'
    assert_includes mail.html_part.body.to_s, '/dashboard/P4'
    assert_includes mail.text_part.body.to_s, 'Comments received: 3'
  end

  def test_read_notification_is_not_sent_in_digest
    settings = create_settings
    notification = FactoryBot.create(
      :notification,
      recipient: settings.user,
      read_at: Time.current,
      email_processed_at: Time.current
    )

    assert_no_emails do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_nil notification.reload.email_sent_at
  end

  def test_an_unread_overseer_failure_is_carried_by_the_digest
    settings = create_settings
    notification = FactoryBot.create(:notification, recipient: settings.user, kind: 'overseer_failed')

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_not_nil notification.reload.email_sent_at
  end

  def test_opted_out_failure_notifications_are_not_carried_by_the_digest
    settings = create_settings
    settings.update!(
      channels: settings.channels.merge(
        'overseer_failed' => ['in_app'],
        'pdf_generation_failed' => ['in_app']
      )
    )
    overseer_failure = FactoryBot.create(:notification, recipient: settings.user, kind: 'overseer_failed')
    pdf_failure = FactoryBot.create(:notification, recipient: settings.user, kind: 'pdf_generation_failed')

    assert_no_emails do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    [overseer_failure, pdf_failure].each do |notification|
      assert_not_nil notification.reload.email_processed_at
      assert_nil notification.email_sent_at
    end
  end

  def test_an_unread_discussion_deadline_is_carried_by_the_digest
    settings = create_settings
    notification = FactoryBot.create(:notification, recipient: settings.user, kind: 'discuss_warning')

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_not_nil notification.reload.email_processed_at
    assert_not_nil notification.email_sent_at
  end

  def test_unit_email_master_switch_processes_without_sending
    settings = create_settings
    notification = FactoryBot.create(:notification, recipient: settings.user)
    notification.unit.update!(send_notifications: false)

    assert_no_emails do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_not_nil notification.reload.email_processed_at
    assert_nil notification.email_sent_at
  end

  def test_a_muted_unit_is_processed_without_sending
    settings = create_settings
    notification = FactoryBot.create(:notification, recipient: settings.user)
    NotificationUnitOverride.create!(user: settings.user, unit: notification.unit, muted: true)

    assert_no_emails do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_not_nil notification.reload.email_processed_at
    assert_nil notification.email_sent_at
  end

  def test_pruning_removes_old_read_history_but_retains_unread_events
    old_read = FactoryBot.create(:notification, read_at: 91.days.ago)
    old_unread = FactoryBot.create(:notification, created_at: 91.days.ago)

    PruneNotificationsJob.new.perform

    assert_not Notification.exists?(old_read.id)
    assert Notification.exists?(old_unread.id)
  end
end
