class AcceptSubmissionJob
  include Sidekiq::Job

  def perform(task_id, user_id)
    task = Task.find(task_id)
    user = User.find(user_id)

    # Convert submission to PDF
    task.convert_submission_to_pdf

    # When converted, we can now send documents to turn it in for checking
    if TurnItIn.functional?
      TurnItIn.send_documents_to_tii(task, user)
    end

    # rescue to raise error message to avoid unnecessary retry
  end
end
