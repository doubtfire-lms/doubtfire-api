# frozen_string_literal: true

require 'test_helper'
class TiiCheckProgressJobTest < ActiveSupport::TestCase

  def test_jobs_are_scheduled
    Sidekiq::Cron::Job.destroy_all!
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(Rails.root.join('config/schedule.yml')))
    assert_equal 9, Sidekiq::Cron::Job.all.count, Sidekiq::Cron::Job.all.map(&:name)

    Sidekiq::Cron::Job.all.each(&:enqueue!)
    assert_equal 1, TiiRegisterWebHookJob.jobs.count
    assert_equal 1, TiiCheckProgressJob.jobs.count
    assert_equal 1, ClearAccessTokensJob.jobs.count
    assert_equal 1, RefreshModerationFeedbackTimestampsJob.jobs.count
    assert_equal 1, AggregateTaskCompletionStatsJob.jobs.count
    assert_equal 1, PollCommunicationSetSchedulesJob.jobs.count
    assert_equal 1, NotifyDiscussTimeoutJob.jobs.count
    # assert_equal 1, ArchiveOldUnitsJob.jobs.count
  end

end
