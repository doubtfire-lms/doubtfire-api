# frozen_string_literal: true

# Runs once early on Monday. Each user's next digest picks up the summaries.
class CreateWeeklySummaryNotificationsJob
  include Sidekiq::Job

  sidekiq_options queue: 'parallel',
                  lock: :until_executed,
                  lock_args_method: ->(_args) { ['create-weekly-summary-notifications'] },
                  on_conflict: :reject,
                  retry: 2

  def perform(at = nil)
    week_end = at.present? ? Time.zone.parse(at) : Time.current
    week_start = week_end - 7.days
    summary_stats = {
      week_end: week_end,
      week_start: week_start,
      weeks_comments: TaskComment.where(created_at: week_start...week_end).count,
      weeks_engagements: TaskEngagement.where(engagement_time: week_start...week_end).count
    }

    Unit.within_last_teaching_date(week_end)
        .where(send_notifications: true, start_date: ...week_end)
        .find_each do |unit|
      unit.create_weekly_summary_notifications(summary_stats)
    end
  end
end
