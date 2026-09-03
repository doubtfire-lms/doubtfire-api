require 'test_helper'

class NotificationSettingTest < ActiveSupport::TestCase
  def test_default_digest_timezone_falls_back_when_tz_is_unset
    original_timezone = ENV.delete('TZ')

    assert_equal Time.zone.tzinfo.name, NotificationSetting.default_digest_timezone
  ensure
    ENV['TZ'] = original_timezone if original_timezone
  end

  def test_defaults_to_a_monday_morning_digest_on_every_channel_but_push
    settings = NotificationSetting.for(FactoryBot.create(:user))

    assert_equal 'weekly', settings.digest_frequency
    assert_equal 4, settings.digest_interval_hours
    assert_equal '08:00', settings.digest_start_time
    assert_equal '07:00', settings.digest_time
    assert_equal NotificationSetting.default_digest_timezone, settings.digest_timezone
    assert_equal 1, settings.digest_weekday
    assert settings.weekly_summary
    assert_equal %w[in_app email], settings.channels['new_task_comment']
    assert_equal ['in_app'], settings.channels['communication_email']
    assert_equal Notification::KINDS.sort, settings.channels.keys.sort
  end

  def test_a_unit_without_a_preference_follows_the_defaults
    settings = NotificationSetting.for(FactoryBot.create(:user))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    assert settings.delivers?(unit, 'new_task_comment', :email)
    assert_not settings.delivers?(unit, 'new_task_comment', :push)
  end

  def test_a_customised_unit_uses_its_own_channels
    settings = NotificationSetting.for(FactoryBot.create(:user))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    FactoryBot.create(
      :notification_unit_override,
      user: settings.user,
      unit: unit,
      channels: { 'new_task_comment' => ['push'] }
    )

    assert_not settings.delivers?(unit, 'new_task_comment', :email)
    assert settings.delivers?(unit, 'new_task_comment', :push)
  end

  def test_a_muted_unit_delivers_nothing
    settings = NotificationSetting.for(FactoryBot.create(:user))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    FactoryBot.create(:notification_unit_override, user: settings.user, unit: unit, muted: true)

    assert_empty settings.channels_for_unit_id(unit.id, 'new_task_comment')
  end

  def test_weekly_summary_honours_the_global_setting_and_unit_mute
    settings = NotificationSetting.for(FactoryBot.create(:user))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    assert settings.weekly_summary_for?(unit)

    FactoryBot.create(:notification_unit_override, user: settings.user, unit: unit, muted: true)
    assert_not settings.weekly_summary_for?(unit)

    settings.update!(weekly_summary: false)
    other_unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    assert_not settings.weekly_summary_for?(other_unit)
  end

  def test_a_muted_unit_keeps_following_the_defaults_underneath
    settings = NotificationSetting.for(FactoryBot.create(:user))
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    preference = FactoryBot.create(
      :notification_unit_override,
      user: settings.user,
      unit: unit,
      muted: true
    )

    assert_not preference.customised?

    preference.update!(muted: false)
    assert settings.delivers?(unit, 'new_task_comment', :email)
  end

  def test_daily_delivery_keeps_its_time_across_a_daylight_saving_transition
    user = FactoryBot.create(:user)
    campus = FactoryBot.create(:campus, timezone: 'Australia/Melbourne')
    FactoryBot.create(:project, user: user, campus: campus)
    settings = FactoryBot.build(
      :notification_setting,
      user: user,
      digest_frequency: 'daily',
      digest_time: '09:00'
    )
    from = Time.zone.local(2026, 10, 3, 13, 30, 0)

    next_occurrence = settings.next_occurrence(from)

    assert_equal Date.new(2026, 10, 4), next_occurrence.to_date
    assert_equal 9, next_occurrence.hour
  end

  def test_delivery_uses_the_first_enrolled_projects_campus_timezone
    user = FactoryBot.create(:user)
    first_campus = FactoryBot.create(:campus, timezone: 'Australia/Melbourne')
    second_campus = FactoryBot.create(:campus, timezone: 'Pacific/Auckland')
    FactoryBot.create(:project, user: user, campus: first_campus, enrolled: true)
    FactoryBot.create(:project, user: user, campus: second_campus, enrolled: true)
    settings = FactoryBot.build(
      :notification_setting,
      user: user,
      digest_frequency: 'daily',
      digest_time: '08:00'
    )

    next_occurrence = settings.next_occurrence(Time.utc(2026, 7, 28, 21, 30))

    assert_equal Time.utc(2026, 7, 28, 22), next_occurrence
    assert_equal 'Australia/Melbourne', next_occurrence.time_zone.name
  end

  def test_hourly_delivery_continues_across_midnight_without_drifting
    settings = FactoryBot.build(
      :notification_setting,
      digest_frequency: 'hourly',
      digest_interval_hours: 4,
      digest_start_time: '08:00'
    )
    digest_zone = ActiveSupport::TimeZone[settings.resolved_digest_timezone]

    assert_equal digest_zone.local(2026, 7, 29, 12),
                 settings.next_occurrence(digest_zone.local(2026, 7, 29, 10, 30))
    assert_equal digest_zone.local(2026, 7, 30, 0),
                 settings.next_occurrence(digest_zone.local(2026, 7, 29, 20, 30))
  end

  def test_three_hourly_delivery_continues_from_its_anchor
    settings = FactoryBot.build(
      :notification_setting,
      digest_frequency: 'hourly',
      digest_interval_hours: 3,
      digest_start_time: '08:00'
    )
    digest_zone = ActiveSupport::TimeZone[settings.resolved_digest_timezone]

    assert_equal digest_zone.local(2026, 7, 30, 2),
                 settings.next_occurrence(digest_zone.local(2026, 7, 29, 23, 30))
  end

  def test_weekly_delivery_lands_on_the_selected_weekday
    settings = FactoryBot.build(
      :notification_setting,
      digest_frequency: 'weekly',
      digest_weekday: 3,
      digest_time: '07:00'
    )

    next_occurrence = settings.next_occurrence(Time.zone.local(2026, 7, 29, 10, 0, 0))

    assert_equal 3, next_occurrence.to_date.cwday
    assert_equal 7, next_occurrence.hour
  end

  def test_switching_the_digest_off_processes_notifications_waiting_for_it
    settings = FactoryBot.create(:notification_setting)
    digested = FactoryBot.create(:notification, recipient: settings.user)
    alert = FactoryBot.create(:notification, recipient: settings.user, kind: 'discuss_warning')

    settings.update!(digest_frequency: 'off')

    assert_not_nil digested.reload.email_processed_at
    assert_not_nil alert.reload.email_processed_at
    assert_nil settings.reload.next_digest_at
  end

  def test_unknown_kinds_and_channels_are_rejected
    settings = FactoryBot.build(:notification_setting, channels: { 'unknown' => ['smoke'] })

    assert_not settings.valid?
    assert_includes settings.errors[:channels].join, 'unknown'
    assert_includes settings.errors[:channels].join, 'smoke'
  end

  def test_channels_must_be_an_object
    settings = FactoryBot.build(:notification_setting, channels: ['new_task_comment'])

    assert_not settings.valid?
    assert_includes settings.errors[:channels], 'must be an object'
  end
end
