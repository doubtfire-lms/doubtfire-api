require 'test_helper'

class NotificationPreferenceTest < ActiveSupport::TestCase
  def test_defaults_to_monday_morning_weekly_delivery
    user = FactoryBot.create(:user)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    preference = NotificationPreference.for(user, unit)

    assert_equal 'weekly', preference.email_frequency
    assert_equal '09:00', preference.email_time
    assert_equal 1, preference.email_weekday
    assert_includes preference.email_categories, 'tutor_note'
  end

  def test_default_categories_preserve_legacy_opt_outs_only_when_first_created
    user = FactoryBot.create(
      :user,
      receive_feedback_notifications: false,
      receive_task_notifications: false
    )
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    preference = NotificationPreference.for(user, unit)
    user.update!(
      receive_feedback_notifications: true,
      receive_task_notifications: true
    )

    assert_equal ['tutor_note'], preference.reload.email_categories
  end

  def test_student_default_timezone_uses_their_project_campus
    unit = FactoryBot.create(:unit, task_count: 0)
    project = unit.active_projects.first
    project.campus.update!(timezone: 'Australia/Perth')

    preference = NotificationPreference.for(project.student, unit)

    assert_equal 'Australia/Perth', preference.timezone
  end

  def test_next_occurrence_uses_the_selected_timezone
    preference = FactoryBot.build(
      :notification_preference,
      email_frequency: 'daily',
      email_time: '09:00',
      timezone: 'Australia/Melbourne'
    )
    from = Time.utc(2026, 7, 29, 1, 0, 0)

    next_occurrence = preference.next_occurrence(from)

    assert_equal 9, next_occurrence.in_time_zone('Australia/Melbourne').hour
    assert_operator next_occurrence, :>, from
  end

  def test_daily_delivery_keeps_local_time_across_daylight_saving_transition
    preference = FactoryBot.build(
      :notification_preference,
      email_frequency: 'daily',
      email_time: '09:00',
      timezone: 'Australia/Melbourne'
    )
    from = Time.utc(2026, 10, 3, 13, 30, 0)

    next_occurrence = preference.next_occurrence(from).in_time_zone('Australia/Melbourne')

    assert_equal Date.new(2026, 10, 4), next_occurrence.to_date
    assert_equal 9, next_occurrence.hour
    assert_equal '+11:00', next_occurrence.strftime('%:z')
  end

  def test_switching_delivery_off_processes_existing_pending_notifications
    preference = FactoryBot.create(:notification_preference)
    notification = FactoryBot.create(
      :notification,
      recipient: preference.user,
      unit: preference.unit
    )

    preference.update!(email_frequency: 'off')

    assert_not_nil notification.reload.email_processed_at
    assert_nil preference.reload.next_digest_at
  end

  def test_invalid_categories_are_rejected
    preference = FactoryBot.build(:notification_preference, email_categories: ['unknown'])

    assert_not preference.valid?
    assert_includes preference.errors[:email_categories].join, 'unknown'
  end

  def test_email_categories_must_be_an_array
    preference = FactoryBot.build(:notification_preference, email_categories: 'feedback_left')

    assert_not preference.valid?
    assert_includes preference.errors[:email_categories], 'must be an array'
  end

  def test_email_categories_normalize_a_text_backed_json_value
    preference = FactoryBot.build(
      :notification_preference,
      email_categories: %w[feedback_left tutor_note].to_json
    )

    assert preference.valid?
    assert_equal %w[feedback_left tutor_note], preference.email_categories
  end
end
