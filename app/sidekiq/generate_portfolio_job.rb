class GeneratePortfolioJob
  include Sidekiq::Job
  include LogHelper

  sidekiq_options queue: :portfolio_pdf_gen,
                  lock: :until_and_while_executing,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  # use `retry: false` to execute this once and only once
                  # use `retry: 0` to send the job to the dead queue
                  # We can then look at the dead queue and identify the task ID and user ID
                  retry: 0

  def perform(project_id)
    begin
      # Ensure cwd is valid...
      FileUtils.cd(Rails.root)
    rescue StandardError => e
      logger.error e
      raise e
    end

    begin
      project = Project.find(project_id)
    rescue StandardError => e
      logger.error e
      raise e

      # return
    end

    begin
      # logger.info "Accepting submission for task #{task.id} by user #{user.id}"
      project.create_portfolio
    rescue StandardError => e
      logger.error e
      raise e
      # # Send email to student if task pdf failed
      # if task.project.student.receive_task_notifications
      #   begin
      #     PortfolioEvidenceMailer.task_pdf_failed(task.project, [task]).deliver
      #   rescue StandardError => e
      #     logger.error "Failed to send task pdf failed email for project #{task.project.id}!\n#{e.message}"
      #   end
      # end

      # begin
      #   # Notify system admin
      #   mail = ErrorLogMailer.error_message('Accept Submission', "Failed to convert submission to PDF for task #{task.log_details}", e)
      #   mail.deliver if mail.present?
      # rescue StandardError => e
      #   logger.error "Failed to send error log to admin"
      # end

      # nil
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
    raise e
  end
end
