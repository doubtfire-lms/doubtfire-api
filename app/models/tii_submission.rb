# freeze_string_literal: true

# Turn It In Submission objects track individual files submitted to turn it in for
# processing. This will track objects through the process, from submission until
# we receive the similarity report.
class TiiSubmission < ApplicationRecord
  belongs_to :submitted_by_user, class_name: 'User'
  belongs_to :task

  def error_message
    return nil if error_code.nil?

    case error_code.to_sym
    when :no_user_with_accepted_eula
      'No user has accepted the TII EULA'
    when :excessive_retries
      'Failed due to excessive retries'
    when :malformed_request
      'Request is malformed or missing required data'
    when :authentication_error
      'Authenticated with Turn It In failed - adjust configuration'
    when :missing_submission
      'Submission not found in downloading similarity pdf'
    when :generation_failed
      'PDF failed to generate, status FAILED'
    when :invalid_submission_size_too_large
      'Invalid submission file size, Submission file must be <= to 100 MB'
    when :invalid_submission_size_empty
      'Invalid submission file size, Submission file must be > than 0 MB'
    when :existing_submission
      'Submission already exists'
    when :submission_not_found_when_creating_similarity_report
      'Submission not found in creating similarity report'
    else
      custom_error_message
    end
  end

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
    submission_not_found_when_creating_similarity_report: 9,
  }

  # The user who submitted the file. From this we determine who will
  # submit this to turn it in. It will be the user, their tutor, or
  # the main convenor of the project.
  #
  # @param user [User] the user who is submitting the task
  def submitted_by=(user)
    if user.has_accepted_tii_eula?
      self.submitted_by_user = user
    elsif task.tutor.has_accepted_tii_eula?
      self.submitted_by_user = task.tutor
    elsif task.project.main_convenor_user.has_accepted_tii_eula?
      self.submitted_by_user = task.project.main_convenor_user
    else
      self.submitted_by_user = user
      self.error_code = :no_user_with_accepted_eula
    end
    save
  end

  # The user who submitted the file to turn it in.
  def submitted_by
    submitted_by_user
  end

  enum status: {
    created: 0,
    has_id: 1,
    uploaded: 2,
    submission_complete: 3,
    similarity_report_requested: 4,
    similarity_complete: 5,
    similarity_pdf_requested: 8,
    similarity_pdf_available: 9,
    similarity_pdf_downloaded: 9,
    to_delete: 6,
    deleted: 7
  }

  def status_sym
    status.to_sym
  end

  # Contine process is designed to be run in a background job, polling in
  # case of the need to retry actions. This will ensure submissions progress
  # through turn it in when web hooks fails.
  def continue_process
    return if error? || [:deleted, :similarity_pdf_downloaded].include?(status)

    case status_sym
    when :created
      # get the id and upload, then request similarity report
      fetch_tii_submission_id && upload_file_to_tii
      # We have to wait to request similarity report... wait for callback or manually check
    when :has_id
      # upload then request similarity report
      upload_file_to_tii
      # As above... we have to wait for callback
    when :uploaded
      # check if upload processing is complete - poll
      update_from_submission_status(fetch_tii_submission_status)
    when :submission_complete
      request_similarity_report
    when :similarity_report_requested
      # check if similarity report is ready - poll
      update_from_similarity_status(fetch_tii_similarity_status)
    when :similarity_report_complete
      request_similarity_report_pdf
    when :similarity_pdf_requested
      update_from_pdf_report_status(fetch_tii_similarity_pdf_status)
    when :similarity_pdf_available
      download_similarity_report_pdf
    when :to_delete
      delete_submission
      # do nothing when 'deleted'
    end
  end

  # Call tii and get a new submission id
  #
  # @return [Boolean] true if the submission was created, false otherwise
  def fetch_tii_submission_id
    return true if submission_id.present?
    return false if error_message.present?

    TurnItIn.exec_tca_call "TiiSubmission #{id} - fetching id" do
      # Check to ensure it is a new upload
      # Create a new Submission
      subm = TCAClient::SubmissionApi.new.create_submission(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        tii_submission_data
      )

      # Record the submission id
      self.submission_id = subm.id
      self.status = :has_id
      save

      # If we had to indicate the eula was accepted, then we need to update the user
      unless submitted_by_user.tii_eula_version_confirmed
        submitted_by_user.update(tii_eula_version_confirmed: true)
      end

      true
    end
  rescue TCAClient::ApiError => e
    handle_error e
    false
  end

  # Create a turn it in submission for a task document.
  #
  # @return [TCAClient::SubmissionBase] the turn it in submission for the task
  def tii_submission_data
    result = TCAClient::SubmissionBase.new
    result.metadata = TCAClient::SubmissionBaseMetadata.new

    # Setup the task owners
    if task.group_task?
      result.owner = task.group_submission.submitter_task.student.username
      result.metadata.owners = task.group_submission.tasks.map { |t| @instance.tii_user_for(t.student) }
    else
      result.owner = task.student.username
      result.metadata.owners = [TurnItIn.tii_user_for(task.student)]
    end

    # Set submission title
    result.title = "#{task.task_definition.abbreviation} - #{filename} for #{result.owner}"

    # Set submitter if not the same as the task owner
    result.submitter = submitted_by_user.username

    unless submitted_by_user.tii_eula_version_confirmed
      result.eula = TCAClient::EulaAcceptRequest.new(
        user_id: submitted_by_user.username,
        language: 'en-us',
        accepted_timestamp: submitted_by_user.tii_eula_date,
        version: submitted_by_user.tii_eula_version
      )
    end

    result.metadata.submitter = TurnItIn.tii_user_for(submitted_by_user)
    result.owner_default_permission_set = 'LEARNER'
    result.submitter_default_permission_set = TurnItIn.tii_role_for(task, submitted_by_user)

    result.metadata.group = TurnItIn.create_or_get_group(task.task_definition)
    result.metadata.group_context = TurnItIn.create_or_get_group_context(task.unit)

    result
  end

  # Upload all of the document files to the turn it in submission for a task.
  def upload_file_to_tii
    # Ensure we have a submission id and have not uploaded already
    return false unless submission_id.present? && (status_sym == :has_id || status_sym == :created)
    return false if error_message.present?

    TurnItIn.exec_tca_call "TiiSubmission #{id} - uploading file" do
      api_instance = TCAClient::SubmissionApi.new

      api_instance.upload_submitted_file(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        'binary/octet-stream',
        "inline; filename=#{task.filename_in_zip(idx)}",
        task.read_file_from_done(idx)
      )

      self.status = :uploaded
      save
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 413, symbol: :invalid_submission_size_too_large },
      { code: 422, symbol: :invalid_submission_size_empty },
      { code: 409, symbol: :missing_submission }
    ]

    false
  end

  # Get the turn it in status of the file submission
  #
  # @return [TCAClient::Submission] the submission details
  def fetch_tii_submission_status
    TurnItIn.exec_tca_call "TiiSubmission #{id} - fetching submission status" do
      api_instance = TCAClient::SubmissionApi.new

      # Get Submission Details
      api_instance.get_submiddion_details(TurnItIn.x_turnitin_integration_name, TurnItIn.x_turnitin_integration_version, submission_id)
    end
  rescue TCAClient::ApiError => e
    handle_error e
    nil
  end

  # Update the turn it in submission status based on the status from
  # the web hook or the API request.
  #
  # @param [TCAClient::Submission] response - the submission details
  def update_from_submission_status(response)
    case response.status
    when 'CREATED' #	Submission has been created but no file has been uploaded
      upload_file_to_tii
    when 'PROCESSING' # File contents have been uploaded and the submission is being processed
      retry_request
      # return # do nothing... wait for the webhook
    when 'COMPLETE' # Submission processing is complete
      self.retries = 0
      self.status = :submission_complete
      save
      request_similarity_report
    when 'ERROR' # An error occurred during submission processing; see error_code for details
      self.error_code = :custom_tii_error
      self.custom_error_message = response.error_code
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} #{self.custom_error_message}"
      save
    end
  end

  # Request to generate a similarity report for a task
  #
  # @return [boolean] true if the report was requested, false otherwise
  def request_similarity_report
    return false unless status_sym == :submission_complete

    TurnItIn.exec_tca_call "TiiSubmission #{id} - requesting similarity report" do
      data = TCAClient::SimilarityPutRequest.new(
        generation_settings:
          TCAClient::SimilarityGenerationSettings.new(
            search_repositories: %w[
              INTERNET
              SUBMITTED_WORK
              PUBLICATION
              CROSSREF
              CROSSREF_POSTED_CONTENT
            ],
            auto_exclude_self_matching_scope: 'GROUP_CONTEXT'
          )
      )

      # Request Similarity Report
      TCAClient::SimilarityApi.new.request_similarity_report(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        data
      )

      self.retries = 0
      self.status = :similarity_report_requested
      save

      true
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 409, symbol: :submission_not_created }
    ]

    false
  end

  # Get the similarity report status
  #
  # @return [TCAClient::SimilarityMetadata] the similarity report status
  def fetch_tii_similarity_status
    return nil unless submission_id.present?

    TurnItIn.exec_tca_call "TiiSubmission #{id} - fetching similarity report status" do
      # Get Similarity Report Status
      TCAClient::SimilarityApi.new.get_similarity_report_results(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )
    end
  rescue TCAClient::ApiError => e
    handle_error e
    nil
  end

  # Update the similarity report status based on the status from
  # the web hook or the API request.
  #
  # #param [TCAClient::SimilarityMetadata] response - the similarity report status
  def update_from_similarity_status(response)
    case response.status
    # when 'PROCESSING' # Similarity report is being generated
    #   return
    when 'COMPLETE' # Similarity report is complete
      self.status = :similarity_report_complete
      save
      request_similarity_report_pdf
    end
  end

  # Get the pdf id for a similarity report
  #
  # @return [String] the pdf id of the similarity report
  def request_similarity_report_pdf
    return false unless status_sym == :similarity_report_complete

    TurnItIn.exec_tca_call "TiiSubmission #{id} - requesting similarity report pdf" do
      generate_similarity_pdf = TCAClient::GenerateSimilarityPDF.new(
        locale: 'en-US'
      )

      # Get Similarity Report Status
      result = TCAClient::SimilarityApi.new.request_similarity_report_pdf(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        generate_similarity_pdf
      )

      self.status = :similarity_pdf_requested
      self.similarity_pdf_id = result.id
      save
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, symbol: :submission_not_found_when_creating_similarity_report }
    ]
    nil
  end

  def retry_request
    self.retries += 1
    if self.retries > 10
      self.error_code = :excessive_retries
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} excessive retries"
    else
      next_process_update_at = Time.zone.now + 30.minutes
    end

    save
  end

  def error?
    error_message.present?
  end

  def handle_error(error, codes)
    case error.error_code
    when 400
      self.error_code = :malformed_request
      save
      return
    when 403
      self.error_code = :authentication_error
      save
      return
    when 429
      Doubtfire::Application.config.logger.error "Request has been rejected due to rate limiting - tii_submission #{id}"
      return
    when 0
      self.error_code = :custom_tii_error
      custom_error_message = error.message
    end

    codes.each do |check|
      next unless error.error_code == check[:code]

      self.error_code = check[:symbol]
      # custom_error_message = check[:message] if check[:message].present?
      save
      break
    end
  end

  # Update the status based on the response from the pdf status api or webhook
  #
  # @param [TCAClient::PdfStatusResponse] response - the similarity report status
  def update_from_pdf_report_status(response)
    case response.status
    when 'FAILED' # The report failed to be generated
      error_message = 'similarity PDF failed to be created'
    when 'SUCCESS' # Similarity report is complete
      self.status = :similarity_pdf_requested
      save
      download_similarity_report_pdf
      # else # pending or unknown...
    end
  end

  def download_similarity_report_pdf
    return false unless similarity_pdf_id.present?
    return false unless fetch_similarity_pdf_status == 'SUCCESS'

    TurnItIn.exec_tca_call "TiiSubmission #{id} - downloading similarity report pdf" do
      # GET download pdf
      result = TCAClient::SimilarityApi.new.download_similarity_report_pdf(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        pdf_id
      )

      path = FileHelper.student_work_dir(:plagarism, task)
      filename = File.join(path, FileHelper.sanitized_filename("#{id}-tii.pdf"))
      file = File.new(filename, 'wb')
      begin
        file.write(result)
      ensure
        file.close
      end

      self.status = :similarity_pdf_downloaded
      save

      true
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, symbol: :missing_submission },
      { code: 409, symbol: :generation_failed }
    ]
    false
  end

  # Get the similarity report status for a task
  #
  # @return [String] the status of the similarity report
  def fetch_tii_similarity_pdf_status
    return nil unless submission_id.present? && pdf_id.present?

    TurnItIn.exec_tca_call "TiiSubmission #{id} - fetching similarity report pdf status" do
      # Get Similarity Report Status
      result = TCAClient::SimilarityApi.new.get_similarity_report_pdf_status(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        pdf_id
      )

      result.status
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Submission not found in downloading similarity pdf' },
      { code: 409, message: 'PDF failed to generate, status FAILED' }
    ]
    nil
  end

  # Delete the turn it in submission for a task
  #
  # @return [Boolean] true if the submission was deleted, false otherwise
  def delete_submission
    self.status = :to_delete
    save

    TurnItIn.exec_tca_call "TiiSubmission #{id} - deleting submission" do
      TCAClient::SubmissionApi.new.delete_submission(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )

      Doubtfire::Application.config.logger.info "Deleted tii submission #{id} for task #{task.id}"

      self.status = :deleted
      save
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Submission not found in delete submission' },
      { code: 409, message: 'Submission is in an error state' }
    ]
    false
  end
end
