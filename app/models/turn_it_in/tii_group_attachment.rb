# freeze_string_literal: true

# Turn It In Group Attachment objects track individual template files uploaded
# to assessments in turn it in
class TiiGroupAttachment < ApplicationRecord
  include TurnItInRequestHelper

  belongs_to :task_definition

  before_destroy :delete_attachment

  enum status: {
    created: 0,
    has_id: 1,
    uploaded: 2,
    complete: 3,
    to_delete: 4,
    deleted: 5
  }

  enum error_code: {
    no_error: 0,
    no_user_with_accepted_eula: 1,
    custom_tii_error: 2,
    excessive_retries: 3,
    malformed_request: 4,
    authentication_error: 5,
    missing_submission: 6,
    generation_failed: 7,
    submission_not_created: 8,
    submission_not_found_when_creating_similarity_report: 9
  }

  def status_sym
    status.to_sym
  end

  def self.create_from_task_definition(task_definition, filename)
    contents = task_definition.read_file_from_resources(filename)
    return nil if contents.nil?

    digest = Digest::SHA1.hexdigest(contents)

    result = TiiGroupAttachment.create(
      task_definition: task_definition,
      filename: filename,
      status: :created,
      file_sha1_digest: digest
    )

    result.fetch_tii_group_attachment_id
    result
  end

  # Contine process is designed to be run in a background job, polling in
  # case of the need to retry actions.
  def continue_process
    return if error? || [:deleted, :similarity_pdf_downloaded].include?(status)

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
    return true if group_attachment_id.present?
    return false if error_message.present?

    data = TCAClient::AddGroupAttachmentRequest.new(
      title: filename,
      template: false
    )

    TurnItIn.exec_tca_call "TiiGroupAttachment #{id} - fetching id" do
      resp = TCAClient::GroupsApi.new.add_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        task_definition.tii_group_id,
        data
      )

      self.group_attachment_id = resp.id
      self.status = :has_id
      save_and_reset_retry
    end
  rescue TCAClient::ApiError => e
    handle_error e
    false
  end

  def upload_attachment_to_tii
    TurnItIn.exec_tca_call "TiiGroupAttachment #{id} - uploading attachment" do
      TCAClient::GroupsApi.new.upload_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        task_definition.tii_group_id,
        self.group_attachment_id,
        "Content-Disposition: inline; filename=\"#{filename}\"",
        task_definition.read_file_from_resources(filename)
      )

      self.status = :uploaded
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

  # Delete the turn it in Group Attachment for a task
  #
  # @return [Boolean] true if the Group Attachment was deleted, false otherwise
  def delete_attachment
    self.status = :to_delete
    save

    TurnItIn.exec_tca_call "TiiGroupAttachment #{id} - deleting Group Attachment" do
      TCAClient::GroupsApi.new.delete_group_attachment(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        task_definition.tii_group_id,
        group_attachment_id
      )

      Doubtfire::Application.config.logger.info "Deleted tii Group Attachment #{id}"

      self.status = :deleted
      save_and_reset_retry
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Group Attachment not found in delete GroupAttachment' },
      { code: 409, message: 'Group Attachment is in an error state' }
    ]
    false
  end
end
