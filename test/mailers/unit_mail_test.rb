require 'test_helper'
require 'grade_helper'

class UnitMailTest < ActionMailer::TestCase

  def test_send_summary_email
    unit = FactoryBot.create :unit

    summary_stats = {}

    summary_stats[:week_end] = Date.today
    summary_stats[:week_start] = summary_stats[:week_end] - 7.days
    summary_stats[:weeks_comments] = TaskComment.where("created_at >= :start AND created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:weeks_engagements] = TaskEngagement.where("engagement_time >= :start AND engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count

    unit.send_weekly_status_emails(summary_stats)

    assert_equal unit.active_projects.count + 1, ActionMailer::Base.deliveries.count
  end

end
