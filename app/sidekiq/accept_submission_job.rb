class AcceptSubmissionJob
  include Sidekiq::Job
  include LogHelper

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

      return
    end

    # Mark this task for moderation
    tutor_user = task.project.tutor_for(task.task_definition)
    if tutor_user
      tutor = task.unit.unit_role_for(tutor_user)
      if tutor&.should_moderate_task?(task)
        logger.info "Marking task #{task.id} for moderation (project #{task.project.id})"
        task.mark_as_moderated
      end
    end

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.enabled?
      task.send_documents_to_tii(user, accepted_tii_eula: accepted_tii_eula)
    end

    if task.overseer_enabled? || test_submission
      overseer_assessment = OverseerAssessment.create_for(task, test_submission)
      if overseer_assessment.present?
        logger.info "Launching Overseer assessment for task_def_id: #{task.task_definition.id} task_id: #{task.id}"

        overseer_assessment.send_to_overseer(test_submission: test_submission)

      else
        logger.info "Overseer assessment for task_def_id: #{task.task_definition.id} task_id: #{task.id} was not performed #{overseer_assessment.inspect}"
      end
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
    task.clear_in_process
  end
end
