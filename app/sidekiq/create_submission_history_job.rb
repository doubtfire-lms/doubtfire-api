class CreateSubmissionHistoryJob
  include Sidekiq::Job
  include LogHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first, 'submission-history'] },
                  on_conflict: :reject,
                  retry: false

  def perform(task_id, submission_timestamp, test_submission)
    task = Task.find(task_id)
    history = SubmissionHistory.create_archive!(task, submission_timestamp)

    return unless task.overseer_enabled? || test_submission

    assessment = OverseerAssessment.create_for(history, test_submission)
    return if assessment.nil?

    assessment.update!(student_notified_at: Time.current) if test_submission
    assessment.send_to_overseer(test_submission: test_submission)
  rescue StandardError => e
    logger.error e
    Sentry.capture_exception(e, extra: { task_id: task_id }) if defined?(Sentry)
  ensure
    SubmissionHistory.clear_pending(task) if task
  end
end
