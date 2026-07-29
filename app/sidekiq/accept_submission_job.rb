class AcceptSubmissionJob
  include Sidekiq::Job
  include LogHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(task_id, user_id, accepted_tii_eula, test_submission)
    begin
      # Ensure cwd is valid...
      FileUtils.cd(Rails.root)
    rescue StandardError => e
      logger.error e
    end

    begin
      task = Task.find(task_id)
      user = User.find(user_id)
    rescue StandardError => e
      logger.error e
      return
    end

    begin
      logger.info "Accepting submission for task #{task.id} by user #{user.id}"
      # Convert submission to PDF
      task.convert_submission_to_pdf(log_to_stdout: true)
    rescue StandardError => e
      logger.error e

      Notification.create_pdf_failure(task)

      begin
        # Notify system admin
        if defined?(Sentry)
          Sentry.capture_exception(
            e,
            extra: {
              task_id: task.id,
              task_definition_abbreviation: task.task_definition.abbreviation,
              latex_log_message: e.respond_to?(:log_message) ? e.log_message.to_s.last(5000) : nil
            }
          )
        end
        mail = ErrorLogMailer.error_message('Accept Submission', "Failed to convert submission to PDF for task #{task.log_details}", e)
        mail.deliver if mail.present?
      rescue StandardError => e
        logger.error "Failed to send error log to admin"
      end

      return
    end

    Notification.resolve_task_kinds(task, 'pdf_generation_failed')

    # Mark this task for moderation
    tutor_user = task.project.tutor_for(task.task_definition)
    if tutor_user && !test_submission
      tutor = task.unit.unit_role_for(tutor_user)
      if tutor&.should_moderate_task?(task)
        logger.info "Marking task #{task.id} for moderation (project #{task.project.id})"
        task.mark_as_moderated
      end
    end

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.enabled? && !test_submission
      task.send_documents_to_tii(user, accepted_tii_eula: accepted_tii_eula)
    end

    if SubmissionHistory.enabled_requirements(task).any?
      submission_timestamp = Time.now.utc.to_i
      SubmissionHistory.mark_pending(task)
      CreateSubmissionHistoryJob.perform_async(task.id, submission_timestamp, test_submission)
    elsif task.overseer_enabled? || test_submission
      logger.error "Overseer assessment was not performed because task definition #{task.task_definition.id} has no submission history files configured"
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
    if defined?(Sentry)
      Sentry.capture_exception(
        e,
        extra: {
          task_id: task&.id,
          task_definition_abbreviation: task&.task_definition&.abbreviation
        }
      )
    end
    task.clear_in_process
  end
end
