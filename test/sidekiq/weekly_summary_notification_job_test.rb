require 'test_helper'

class WeeklySummaryNotificationJobTest < ActiveSupport::TestCase
  def setup
    @monday = Time.zone.local(2026, 7, 27, 3)
    @unit = FactoryBot.create(:unit)
    @unit.update!(start_date: @monday - 1.month, end_date: @monday + 1.month)
    @project = @unit.active_projects.first
    settings = NotificationSetting.for(@project.student)
    settings.update!(channels: settings.channels.merge('weekly_summary' => ['in_app']))
  end

  def test_creates_each_opted_in_summary_once
    travel_to(@monday) do
      2.times { CreateWeeklySummaryNotificationsJob.new.perform }
    end

    summaries = Notification.where(recipient: @project.student, unit: @unit, kind: 'weekly_summary')
    assert_equal 1, summaries.count
    assert_equal 'student', summaries.first.weekly_summary_data['audience']
    assert_not_nil summaries.first.email_processed_at
  end

  def test_skips_units_past_their_last_teaching_date
    @unit.update!(last_teaching_date: (@monday - 1.day).to_date)

    travel_to(@monday) { CreateWeeklySummaryNotificationsJob.new.perform }

    assert_not Notification.exists?(unit: @unit, kind: 'weekly_summary')
  end
end
