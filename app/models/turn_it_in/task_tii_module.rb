# freeze_string_literal: true

# Provides Turnitin integration functionality for Tasks
module TaskTiiModule
  # Send all documents to turn it in for checking
  #
  # @param submitter [User] the user submitting the document to formatif
  def send_documents_to_tii(submitter, accepted_tii_eula: false)
    # for each file in the submission...
    number_of_uploaded_files.times do |idx|
      next unless use_tii?(idx)

      # Check to ensure it is a new upload
      last_tii_submission_for_task = tii_submissions.where(idx: idx).last
      next unless last_tii_submission_for_task.nil? || file_uploaded_at > last_tii_submission_for_task.created_at

      # Create the submission...
      result = TiiSubmission.create(
        task: self,
        idx: idx,
        filename: filename_for_upload(idx),
        submitted_at: Time.zone.now,
        status: :created,
        submitted_by: submitter
      )

      # and start its processing
      TiiActionUploadSubmission.create(
        entity: result,
        params: {
          accepted_tii_eula: accepted_tii_eula
        }
      ).perform
    end
  end
end
