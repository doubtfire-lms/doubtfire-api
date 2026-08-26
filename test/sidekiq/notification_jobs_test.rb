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

  def test_discussion_deadlines_are_left_for_their_own_email
    settings = create_settings
    notification = FactoryBot.create(:notification, recipient: settings.user, kind: 'discuss_warning')

    assert_no_emails do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    assert_nil notification.reload.email_processed_at
    assert_nil notification.email_sent_at
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
