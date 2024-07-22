class AcceptSubmissionJob
  include Sidekiq::Job
  include LogHelper

  def perform(task_id, user_id, accepted_tii_eula)
    begin
      # Ensure cwd is valid...
      FileUtils.cd(Rails.root)
    rescue StandardError => e
      logger.error e
    end

    task = Task.find(task_id)
    user = User.find(user_id)

    begin
      # Convert submission to PDF
      task.convert_submission_to_pdf(log_to_stdout: false)
    rescue StandardError => e
      # Send email to student if task pdf failed
      if task.project.student.receive_task_notifications
        begin
          PortfolioEvidenceMailer.task_pdf_failed(project, [task]).deliver
        rescue StandardError => e
          logger.error "Failed to send task pdf failed email for project #{project.id}!\n#{e.message}"
        end
      end

      logger.error e
      return
    end

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.functional?
      task.send_documents_to_tii(user, accepted_tii_eula: accepted_tii_eula)
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
  end
end
