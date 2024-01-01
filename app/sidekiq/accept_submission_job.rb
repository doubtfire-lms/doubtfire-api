class AcceptSubmissionJob
  include Sidekiq::Job
  include LogHelper

  def perform(task_id, user_id, accepted_tii_eula)
    task = Task.find(task_id)
    user = User.find(user_id)

    # Convert submission to PDF
    task.convert_submission_to_pdf

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.functional?
      task.send_documents_to_tii(user, accepted_tii_eula: accepted_tii_eula)
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
  end
end
