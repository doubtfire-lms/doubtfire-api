class AcceptSubmissionJob
  include Sidekiq::Job
  include LogHelper

  sidekiq_options queue: :task_pdf_gen,
                  lock: :until_and_while_executing,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  # use `retry: false` to execute this once and only once
                  # use `retry: 0` to send the job to the dead queue
                  # We can then look at the dead queue and identify the task ID and user ID
                  retry: 0

  # TODO:  errors should clear the in_process files
  # TODO: this job itself should handle the moving of files
  # TODO: sidekiq should handle the retrying of a failed compile (done in convert_submission_to_pdf)

  def perform(task_id, user_id, accepted_tii_eula)
    begin
      # Ensure cwd is valid...
      FileUtils.cd(Rails.root)
    rescue StandardError => e
      logger.error e
      raise "cwd is invalid"
    end

    # begin
    task = Task.find(task_id)
    user = User.find(user_id)

    unless task.processing_pdf?
      raise "No files to process?"
    end

    # rescue StandardError => e
    #   logger.error e
    #   return
    # end

    begin
      logger.info "Accepting submission for task #{task.id} by user #{user.id}"
      # Convert submission to PDF
      task.convert_submission_to_pdf(log_to_stdout: true)
    rescue StandardError => e
      logger.error e

      # Send email to student if task pdf failed
      if task.project.student.receive_task_notifications
        begin
          PortfolioEvidenceMailer.task_pdf_failed(task.project, [task]).deliver
        rescue StandardError => e
          logger.error "Failed to send task pdf failed email for project #{task.project.id}!\n#{e.message}"
        end
      end

      begin
        # Notify system admin
        mail = ErrorLogMailer.error_message('Accept Submission', "Failed to convert submission to PDF for task #{task.log_details}", e)
        mail.deliver if mail.present?
      rescue StandardError => e
        logger.error "Failed to send error log to admin"
      end
      raise "#{e} - #{task.log_details}"
    end

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.enabled?
      task.send_documents_to_tii(user, accepted_tii_eula: accepted_tii_eula)
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
    task.clear_in_process if task&.valid?
    raise e
  end
end
