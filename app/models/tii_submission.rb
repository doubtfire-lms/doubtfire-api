class TiiSubmission < ApplicationRecord
  belongs_to :submitted_by_user, class_name: 'User'
  belongs_to :task

  def submitted_by= user
    if user.has_accepted_tii_eula?
      self.submitted_by_user = user
    elsif task.tutor.has_accepted_tii_eula?
      self.submitted_by_user = task.tutor
    elsif task.project.main_convenor_user.has_accepted_tii_eula?
      self.submitted_by_user = task.project.main_convenor_user
    else
      self.submitted_by_user = user
      self.error_message = 'No user has accepted the TII EULA'
    end
    save
  end

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

  # Contine process is designed to be run in a background job, polling in
  # case of the need to retry actions. This will ensure submissions progress
  # through turn it in when web hooks fails.
  def continue_process
    return if has_error? || [:deleted, :similarity_pdf_downloaded].include?(status)

    case status
    when :created
      # get the id and upload, then request similarity report
      fetch_tii_submission_id && upload_file_to_tii && request_similarity_report
    when :has_id
      # upload then request similarity report
      upload_file_to_tii && request_similarity_report
    when :uploaded
      # check if upload processing is complete - poll
      update_from_submission_status(fetch_tii_submission_status)
    when :submission_complete
      request_similarity_report
      return
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
      return
    when 'deleted'
      return
    end
  end

  # Call tii and get a new submission id
  #
  # @return [Boolean] true if the submission was created, false otherwise
  def fetch_tii_submission_id
    return true if submission_id.present?
    return false if error_message.present?

    # Check to ensure it is a new upload
    # Create a new Submission
    subm = TCAClient::SubmissionApi.new.create_submission(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      tii_submission_data
    )

    # Record the submission id
    submission_id = subm.id
    status = :has_id
    save

    if not submitted_by_user.tii_eula_version_confirmed
      submitted_by_user.update(tii_eula_version_confirmed: true)
    end

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Exception when performing a TII submission for task #{task.id}: #{e}"
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

    if not submitted_by_user.tii_eula_version_confirmed
      result.eula = TCAClient::EulaAcceptRequest.new(
        user_id: user.username,
        language: 'en-us',
        accepted_timestamp: submitted_by_user.tii_eula_date,
        version: submitted_by_user.tii_eula_version
      )
    end

    result.metadata.submitter = TurnItIn.tii_user_for(submitter)
    result.owner_default_permission_set = 'LEARNER'
    result.submitter_default_permission_set = TurnItIn.tii_role_for(task, submitter)

    result.metadata.group = TurnItIn.create_or_get_group(task.task_definition)
    result.metadata.group_context = TurnItIn.create_or_get_group_context(task.unit)

    result
  end

  # Upload all of the document files to the turn it in submission for a task.
  def upload_file_to_tii()
    # Ensure we have a submission id and have not uploaded already
    return false unless submission_id.present? && (status == :has_id || status == :created)
    return false if error_message.present?

    api_instance = TCAClient::SubmissionApi.new

    api_instance.upload_submitted_file(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      submission_id,
      'binary/octet-stream',
      "inline; filename=#{task.filename_in_zip(idx)}",
      task.read_file_from_done(idx)
    )

    submission_status = :uploaded
    save
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to upload submission to turn it in #{id} - #{e}"

    handle_error e, [
      {code: 413, message: 'Invalid submission file size, Submission file must be <= to 100 MB'},
      { code: 422, message: 'Invalid submission file size, Submission file must be > than 0 MB'},
      { code: 409, message: 'Submission already exists' }
    ]

    false
  end

  # Get the turn it in status of the file submission
  #
  # @return [TCAClient::Submission] the submission details
  def fetch_tii_submission_status
    api_instance = TCAClient::SubmissionApi.new

    # Get Submission Details
    api_instance.get_submiddion_details(TurnItIn.x_turnitin_integration_name, TurnItIn.x_turnitin_integration_version, submission_id)
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Error when calling SubmissionApi->get_submission_details: #{e}"

    handle_error e

    nil
  end

  # Update the turn it in submission status based on the status from
  # the web hook or the API request.
  #
  # @param [TCAClient::Submission] response - the submission details
  def update_from_submission_status(response)
    case response.status
    when 'CREATED': #	Submission has been created but no file has been uploaded
      upload_file_to_tii
    when 'PROCESSING': # File contents have been uploaded and the submission is being processed
      retry_request
      return # do nothing... wait for the webhook
    when 'COMPLETE': # Submission processing is complete
      status = :submission_complete
      save
      request_similarity_report
    when 'ERROR': # An error occurred during submission processing; see error_code for details
      error_message = response.error_code
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} #{error_message}"
      save
    end
  end

  # Request to generate a similarity report for a task
  #
  # @return [boolean] true if the report was requested, false otherwise
  def request_similarity_report
    return false unless submission_status == :submission_complete

    data = TCAClient::SimilarityPutRequest.new(
      generation_settings:
        TCAClient::SimilarityGenerationSettings.new(
          search_repositories: [
            'INTERNET',
            'SUBMITTED_WORK',
            'PUBLICATION',
            'CROSSREF',
            'CROSSREF_POSTED_CONTENT'
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

    status = :similarity_report_requested
    save

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Error when calling SubmissionApi->request_similarity_report: #{e}"

    handle_error e, [
      { code: 409, message: 'Submission has not been created yet' }
    ]

    false
  end

  # Get the similarity report status
  #
  # @return [TCAClient::SimilarityMetadata] the similarity report status
  def fetch_tii_similarity_status
    return nil unless submission_id.present?

    # Get Similarity Report Status
    TCAClient::SimilarityApi.new.get_similarity_report_results(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      submission_id
    )
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Error when calling SimilarityApi->get_similarity_report_results: tii submission #{id} #{e}"

    handle_error e

    nil
  end

  # Update the similarity report status based on the status from
  # the web hook or the API request.
  #
  # #param [TCAClient::SimilarityMetadata] response - the similarity report status
  def update_from_similarity_status(response)
    case response.status
    when 'PROCESSING': # Similarity report is being generated
      return
    when 'COMPLETE': # Similarity report is complete
      status = :similarity_report_complete
      save
      request_similarity_report_pdf
    end
  end

  # Get the pdf id for a similarity report
  #
  # @return [String] the pdf id of the similarity report
  def request_similarity_report_pdf()
    return false unless status == :similarity_report_complete

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

    status = :similarity_pdf_requested
    similarity_pdf_id = result.id
    save
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error  "Error when calling SimilarityApi->get_similarity_report_status: #{id} #{e}"

    handle_error e, [
      { code: 404, message: 'Submission not found in creating similarity report' }
    ]

    nil
  end

  def retry_request
    retries++
    if retries > 10
      error_message = "excessive retries"
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} excessive retries"
    else
      next_process_update_at = Time.zone.now + 30.minutes
    end

    save
  end

  def has_error?
    error_message.present?
  end

  def handle_error(e, codes)
    case e.error_code
    when 400:
      error_message = 'Request is malformed or missing required data'
      save
      return
    when 403:
      error_message = 'Not Properly Authenticated'
      save
      return
    when 429:
      Doubtfire::Application.config.logger.error "Request has been rejected due to rate limiting - tii_submission #{id}"
      return
    end

    for check in codes do
      if e.error_code == check[:code]
        error_message = check[:message]
        save
        return
      end
    end
  end

  # Update the status based on the response from the pdf status api or webhook
  #
  # @param [TCAClient::SimilarityReportStatus] response - the similarity report status
  def update_from_pdf_report_status(response)
    case response.status
    when 'FAILED': # The report failed to be generated
      error_message = 'similarity PDF failed to be created'
    when 'SUCCESS': # Similarity report is complete
      status = :similarity_pdf_requested
      save
      download_similarity_report_pdf
    else # pending or unknown...

    end
  end

  def download_similarity_report_pdf
    return false unless similarity_pdf_id.present?
    return false unless fetch_similarity_pdf_status == 'SUCCESS'

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

    status = :similarity_pdf_downloaded
    save

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error  "Error when calling SimilarityApi->download_similarity_report_pdf: #{e}"

    handle_error e, [
      { code: 404, message: 'Submission not found in downloading similarity pdf' },
      { code: 409, message: 'PDF failed to generate, status FAILED' }
    ]

    false
  end

  # Get the similarity report status for a task
  #
  # @return [String] the status of the similarity report
  def fetch_tii_similarity_pdf_status
    return nil unless submission_id.present? && pdf_id.present?

    # Get Similarity Report Status
    result = TCAClient::SimilarityApi.new.get_similarity_report_pdf_status(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      submission_id,
      pdf_id
    )

    result.status
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Error when calling SimilarityApi->get_similarity_report_status: #{e}"

    handle_error e, [
      { code: 404, message: 'Submission not found in downloading similarity pdf' },
      { code: 409, message: 'PDF failed to generate, status FAILED' }
    ]

    nil
  end

  # Delete the turn it in submission for a task
  #
  # @return [Boolean] true if the submission was deleted, false otherwise
  def delete_submission()
    submission_status = :to_delete
    save

    TCAClient::SubmissionApi.new.delete_submission(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      submission_id
    )

    Doubtfire::Application.config.logger.info "Deleted tii submission #{id} for task #{task.id}"

    submission_status = :deleted
    save
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Exception when deleting TII submission #{id}: #{e}"

    handle_error e, [
      { code: 404, message: 'Submission not found in delete submission' },
      { code: 409, message: 'Submission is in an error state' }
    ]

    false
  end
end
