# frozen_string_literal: true

require 'test_helper'
class TiiCheckProgressJobTest < ActiveSupport::TestCase

  def test_jobs_are_scheduled
    Sidekiq::Cron::Job.load_from_hash YAML.load_file("#{Rails.root}/config/schedule.yml")
    Sidekiq::Cron::Job.all.each(&:enque!)
    assert_equal 2, Sidekiq::Cron::Job.all.count

    assert_equal 1, TiiRegisterWebHookJob.jobs.count
    assert_equal 1, TiiCheckProgressJob.jobs.count
  end

end
