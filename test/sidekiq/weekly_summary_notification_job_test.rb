require 'test_helper'

class WeeklySummaryNotificationJobTest < ActiveSupport::TestCase
  class FakeRedis
    def initialize
      @store = {}
    end

    def get(key)
      @store[key]
    end

    def set(key, value, **_options)
      @store[key] = value
      'OK'
    end
  end

  def test_creates_an_opted_in_summary_at_seven_in_the_recipients_timezone_once
    monday_at_seven = Time.utc(2026, 7, 26, 21, 5) # Monday 07:05 in Melbourne.
    unit = FactoryBot.create(:unit)
    unit.update!(start_date: monday_at_seven - 1.month, end_date: monday_at_seven + 1.month)
    project = unit.active_projects.first
    project.campus.update!(timezone: 'Australia/Melbourne')
    settings = NotificationSetting.for(project.student)
    settings.update!(channels: settings.channels.merge('weekly_summary' => ['in_app']))
    redis = FakeRedis.new

    with_sidekiq_redis(redis) do
      CreateWeeklySummaryNotificationsJob.new.perform((monday_at_seven - 10.minutes).iso8601)
      assert_not Notification.exists?(recipient: project.student, unit: unit, kind: 'weekly_summary')

      CreateWeeklySummaryNotificationsJob.new.perform(monday_at_seven.iso8601)
      CreateWeeklySummaryNotificationsJob.new.perform((monday_at_seven + 5.minutes).iso8601)
    end

    summaries = Notification.where(recipient: project.student, unit: unit, kind: 'weekly_summary')
    assert_equal 1, summaries.count
    assert_equal 'student', summaries.first.weekly_summary_data['audience']
    assert_not_nil summaries.first.email_processed_at
  end

  private

  def with_sidekiq_redis(redis)
    original = Sidekiq.method(:redis)
    Sidekiq.define_singleton_method(:redis) { |&redis_block| redis_block.call(redis) }
    yield
  ensure
    Sidekiq.define_singleton_method(:redis, original)
  end
end
