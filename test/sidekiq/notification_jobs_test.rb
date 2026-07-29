require 'test_helper'

class NotificationJobsTest < ActiveSupport::TestCase
  def test_digest_sends_only_enabled_unread_events
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    user = FactoryBot.create(:user)
    preference = FactoryBot.create(
      :notification_preference,
      user: user,
      unit: unit,
      email_categories: ['feedback_left'],
      next_digest_at: 1.minute.ago
    )
    enabled = FactoryBot.create(:notification, recipient: user, unit: unit, kind: 'feedback_left')
    disabled = FactoryBot.create(:notification, recipient: user, unit: unit, kind: 'pdf_generation_failed')

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(preference.id)
    end

    digest_html = ActionMailer::Base.deliveries.last.html_part.body.to_s
    assert_equal 1, digest_html.scan('<style type="text/css">').count
    assert_includes digest_html, '/assets/images/logo.png'
    assert_includes digest_html, 'notification-box'
    assert_includes digest_html, 'Unsubscribe'
    assert_includes digest_html, "on behalf of #{unit.main_convenor_user.name}"

    assert_not_nil enabled.reload.email_sent_at
    assert_not_nil disabled.reload.email_processed_at
    assert_nil disabled.email_sent_at
  end

  def test_read_notification_is_not_sent_in_digest
    preference = FactoryBot.create(:notification_preference, next_digest_at: 1.minute.ago)
    notification = FactoryBot.create(
      :notification,
      recipient: preference.user,
      unit: preference.unit,
      read_at: Time.current,
      email_processed_at: Time.current
    )

    assert_no_emails do
      SendNotificationDigestJob.new.perform(preference.id)
    end

    assert_nil notification.reload.email_sent_at
  end

  def test_digest_leaves_an_overseer_event_pending_until_its_email_delay_expires
    preference = FactoryBot.create(
      :notification_preference,
      email_categories: ['overseer_failed'],
      next_digest_at: 1.minute.ago
    )
    notification = FactoryBot.create(
      :notification,
      recipient: preference.user,
      unit: preference.unit,
      kind: 'overseer_failed',
      metadata: { email_not_before: 20.minutes.from_now.iso8601 }
    )

    assert_no_emails do
      SendNotificationDigestJob.new.perform(preference.id)
    end

    assert_nil notification.reload.email_processed_at
    assert_nil notification.email_sent_at
  end

  def test_unit_email_master_switch_processes_without_sending
    preference = FactoryBot.create(:notification_preference, next_digest_at: 1.minute.ago)
    preference.unit.update!(send_notifications: false)
    notification = FactoryBot.create(
      :notification,
      recipient: preference.user,
      unit: preference.unit
    )

    assert_no_emails do
      SendNotificationDigestJob.new.perform(preference.id)
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
