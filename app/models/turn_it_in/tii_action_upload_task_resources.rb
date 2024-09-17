# freeze_string_literal: true

# Keep track of the group attachments uploaded from task resources
class TiiActionUploadTaskResources < TiiAction
  delegate :status, :status_sym, :tii_group_id, :task_definition, :filename, :group_attachment_id, to: :entity

  def description
    "Upload assessment resources #{filename} for #{entity.task_definition.abbreviation} in #{entity.task_definition.unit.code}"
  end

  def update_from_attachment_status(response)
    return if response.nil?

    case response.status
    when 'COMPLETE'
      entity.status = :complete
      entity.save

      save_and_mark_complete
    when 'ERROR'
      save_and_log_custom_error "Error with tii submission #{id} - #{response.error_code}"
    end
  end

  private

  def run
    if tii_group_id.blank?
      save_and_log_custom_error "Group id does not exist for task definition #{task_definition.id} - cannot upload group attachments"
      return
    end

    return if error? || [:deleted, :complete].include?(status)

    case status_sym
    when :created
      # get the id and upload, then request similarity report
      fetch_tii_group_attachment_id && upload_attachment_to_tii
      # We have to wait to request similarity report... wait for callback or manually check
    when :has_id
      # upload then request similarity report
      upload_attachment_to_tii
      # As above... we have to wait for callback
    when :uploaded
      # Check progress
      update_from_attachment_status(fetch_tii_attachment_status)
    when :to_delete
      delete_attachment
    end
  end

  def fetch_tii_group_attachment_id
    return true if entity.group_attachment_id.present?
    return false if error_message.present?

    data = TCAClient::AddGroupAttachmentRequest.new(
      title: entity.filename,
      template: false
    )

    error_code = [
      { code: 404, message: 'Assessment not found in turn it in' }
    ]

    exec_tca_call "TiiGroupAttachment #{entity.id} - fetching id", error_code do
      resp = TCAClient::GroupsApi.new.add_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        tii_group_id,
        data
      )

      entity.group_attachment_id = resp.id
      entity.status = :has_id
      entity.save

      save_and_reschedule
    end
  end

  def upload_attachment_to_tii
    error_codes = [
      { code: 413, symbol: :invalid_submission_size_too_large },
      { code: 422, symbol: :invalid_submission_size_empty },
      { code: 409, symbol: :missing_submission },
      { code: 404, message: "Assessment not found in TurnItIn" }
    ]

    exec_tca_call "TiiGroupAttachment #{entity.id} - uploading attachment", error_codes do
      TCAClient::GroupsApi.new.upload_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        tii_group_id,
        group_attachment_id,
        "Content-Disposition: inline; filename=\"#{filename}\"",
        task_definition.read_file_from_resources(filename)
      )

      entity.update(status: :uploaded)
      save_and_reschedule
    end
  end

  # Get the status of a group attachment
  #
  # @return [TCAClient::GroupAttachmentResponse] the status of the group attachment
  def fetch_tii_attachment_status
    exec_tca_call "TiiGroupAttachment #{id} - fetching attachment status" do
      TCAClient::GroupsApi.new.get_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        task_definition.tii_group_id,
        group_attachment_id
      )
    end
  end
end
