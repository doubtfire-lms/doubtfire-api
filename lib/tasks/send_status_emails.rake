namespace :mailer do
  task send_status_emails: :environment do
    summary_stats = {}

    summary_stats[:week_end] = Time.zone.today
    summary_stats[:week_start] = summary_stats[:week_end] - 7.days
    summary_stats[:weeks_comments] = TaskComment.where("created_at >= :start AND created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:weeks_engagements] = TaskEngagement.where("engagement_time >= :start AND engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count

    Unit.where(active: true).find_each do |unit|
      next unless summary_stats[:week_end] > unit.start_date && summary_stats[:week_start] < unit.end_date

      unit.send_weekly_status_emails(summary_stats)
    end
  end
end
