# frozen_string_literal: true

require 'test_helper'

class QueueRoutingTest < ActiveSupport::TestCase
  DEFAULT_JOBS = %w[
    AcceptSubmissionJob
    AcceptOverseerJob
    CreateSubmissionHistoryJob
  ].freeze

  PARALLEL_JOBS = %w[
    AggregateTaskCompletionStatsJob
    ArchiveOldUnitsJob
    ClearAccessTokensJob
    CommunicationRuleJob
    CreateWeeklySummaryNotificationsJob
    D2lPostGradesJob
    DownloadMarkingSessionsJob
    DownloadOverflowTaskClaimsCsvJob
    DownloadPortfoliosJob
    DownloadSubmissionFilesJob
    DownloadSubmissionPdfsJob
    DownloadTaskAssessmentCountsCsvJob
    DownloadTaskCompletionCsvJob
    DownloadTasksAwaitingFeedbackCsvJob
    DownloadTutorAssessmentStatsJob
    DownloadUnitTutorTimesSummaryJob
    ExecuteCommunicationSetJob
    ExecuteCommunicationSetScheduleJob
    ImportBatchFeedbackJob
    ImportGradesCsvJob
    ImportLmsExtensionsJob
    ImportLmsStudentsJob
    ImportStaffNotesCsvJob
    ImportStudentsCsvJob
    ImportStudentsJob
    ImportStudentsLtiJob
    LoginDockerJob
    NotifyDiscussTimeoutJob
    NotifyFeedbackWarningsJob
    NotifyTaskDeadlinesJob
    NotifyTutorNotesJob
    PollCommunicationSetSchedulesJob
    PollNotificationDigestsJob
    PruneNotificationsJob
    PullDockerImageJob
    RefreshModerationFeedbackTimestampsJob
    SendDiscussTimeoutEmailJob
    SendNotificationDigestJob
    SyncLmsGradesJob
    SyncLmsIntegrationsJob
    TiiActionJob
    TiiCheckProgressJob
    TiiRegisterWebHookJob
  ].freeze

  def test_every_sidekiq_job_has_the_planned_queue
    job_names = Dir.glob(Rails.root.join('app/sidekiq/*_job.rb').to_s).map do |path|
      File.basename(path, '.rb').camelize
    end
    assert_equal job_names.sort, (DEFAULT_JOBS + PARALLEL_JOBS).sort

    DEFAULT_JOBS.each do |job_name|
      assert_equal 'default', job_name.constantize.get_sidekiq_options['queue'], job_name
    end

    PARALLEL_JOBS.each do |job_name|
      assert_equal 'parallel', job_name.constantize.get_sidekiq_options['queue'], job_name
    end
  end

  def test_one_process_runs_parallel_jobs_and_serial_submission_jobs
    config = YAML.safe_load(Rails.root.join('config/sidekiq.yml').read, permitted_classes: [Symbol])

    assert_equal ['parallel'], config[:queues]
    assert_equal 4, config[:concurrency]
    assert_equal ['default'], config.dig(:capsules, :submission, :queues)
    assert_equal 1, config.dig(:capsules, :submission, :concurrency)
  end
end
