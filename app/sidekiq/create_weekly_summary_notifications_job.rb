# frozen_string_literal: true

require 'set'

class CreateWeeklySummaryNotificationsJob
  include Sidekiq::Job

  PROCESSED_KEY_PREFIX = 'notifications:weekly_summary:created'

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['create-weekly-summary-notifications'] },
                  on_conflict: :reject,
                  retry: 2

  def perform(at = nil)
    create_summaries(at: at, force: false)
  end

  def perform_now
    create_summaries(at: nil, force: true)
  end

  private

  def create_summaries(at:, force:)
    week_end = at.present? ? Time.zone.parse(at) : Time.current
    due_timezones = due_settings_by_timezone(week_end, force: force).reject do |timezone, _settings|
      timezone_processed?(timezone, week_end)
    end
    recipient_ids = due_timezones.values.flatten.to_set(&:user_id)
    return if recipient_ids.empty?

    summary_stats = {
      week_end: week_end,
      week_start: week_end - 7.days,
      weeks_comments: TaskComment.where(created_at: (week_end - 7.days)...week_end).count,
      weeks_engagements: TaskEngagement.where(engagement_time: (week_end - 7.days)...week_end).count
    }

    project_units = Project.where(user_id: recipient_ids, enrolled: true).select(:unit_id)
    role_units = UnitRole.where(user_id: recipient_ids).select(:unit_id)
    units = Unit.where(id: project_units).or(Unit.where(id: role_units))

    units.where(active: true, send_notifications: true).find_each do |unit|
      next unless week_end > unit.start_date && summary_stats[:week_start] < unit.end_date

      unit.create_weekly_summary_notifications(summary_stats, recipient_ids: recipient_ids)
    end

    due_timezones.each_key { |timezone| mark_timezone_processed(timezone, week_end) }
  end

  def due_settings_by_timezone(at, force:)
    NotificationSetting.includes(user: :notification_unit_overrides).find_each.select do |settings|
      (force || settings.weekly_summary_due?(at)) && settings.weekly_summary_opted_in?
    end.group_by(&:digest_timezone)
  end

  def timezone_processed?(timezone, at)
    Sidekiq.redis { |redis| redis.get(processed_key(timezone, at)).present? }
  end

  def mark_timezone_processed(timezone, at)
    Sidekiq.redis { |redis| redis.set(processed_key(timezone, at), '1', ex: 8.days.to_i) }
  end

  def processed_key(timezone, at)
    local_date = at.in_time_zone(timezone).to_date.iso8601
    "#{PROCESSED_KEY_PREFIX}:#{timezone}:#{local_date}"
  end
end
