# freeze_string_literal: true

# Delete a group attachment from turn it in
class TiiActionDeleteSubmission < TiiAction
  def description
    "Delete submission #{params['submission_details']}"
  end

  def run
    submission_id = params["submission_id"]

    if submission_id.blank?
      save_and_log_custom_error "Group Attachment id or Group id does not exist - cannot delete group attachment"
      return
    end

    error_codes = [
      { code: 404, message: 'Submission not found in delete submission' },
      { code: 409, message: 'Submission is in an error state' }
    ]

    exec_tca_call "Deleting Submission #{submission_id} from Turn It In", error_codes do
      TCAClient::SubmissionApi.new.delete_submission(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )

      self.complete = save
      save
    end
  end
end
