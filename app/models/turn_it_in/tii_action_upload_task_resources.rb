# freeze_string_literal: true

# Keep track of the group attachments uploaded from task resources
class TiiActionUploadTaskResources < TiiAction
  def run
    unless entity.tii_group_id.present?
      save_and_log_custom_error "Group id does not exist for task definition #{entity.task_definition.id} - cannot upload group attachments"
      return
    end

    return if error? || [:deleted, :complete].include?(status)

    case entity.status_sym
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

  private

  def fetch_tii_group_attachment_id
    return true if entity.group_attachment_id.present?
    return false if error_message.present?

    data = TCAClient::AddGroupAttachmentRequest.new(
      title: entity.filename,
      template: false
    )

    exec_tca_call "TiiGroupAttachment #{entity.id} - fetching id" do
      resp = TCAClient::GroupsApi.new.add_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        entity.tii_group_id,
        data
      )

      entity.group_attachment_id = resp.id
      entity.status = :has_id
      save_and_reset_retry
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Assessment not found in turn it in' }
    ]
    false
  end

  def upload_attachment_to_tii
    exec_tca_call "TiiGroupAttachment #{entity.id} - uploading attachment" do
      TCAClient::GroupsApi.new.upload_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        entity.tii_group_id,
        entity.group_attachment_id,
        "Content-Disposition: inline; filename=\"#{filename}\"",
        entity.task_definition.read_file_from_resources(filename)
      )

      entity.status = :uploaded
      save_and_reset_retry
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 413, symbol: :invalid_submission_size_too_large },
      { code: 422, symbol: :invalid_submission_size_empty },
      { code: 409, symbol: :missing_submission },
      { code: 404, message: "Assessment not found in TurnItIn" }
    ]
    false
  end

  # Get the status of a group attachment
  #
  # @return [TCAClient::GroupAttachmentResponse] the status of the group attachment
  def fetch_tii_attachment_status
    TurnItIn.exec_tca_call "TiiGroupAttachment #{id} - fetching attachment status" do
      TCAClient::GroupsApi.new.get_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        task_definition.tii_group_id,
        self.group_attachment_id
      )
    end
  rescue TCAClient::ApiError => e
    handle_error e
    nil
  end

  def update_from_attachment_status(response)
    return if response.nil?
    case response.status
    when 'COMPLETE'
      self.status = :complete
      save_and_reset_retry
    when 'ERROR'
      self.error_code = :custom_tii_error
      self.custom_error_message = response.error_code
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} #{self.custom_error_message}"
      save_and_reset_retry
    end
  end

end
