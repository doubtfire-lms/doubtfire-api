# freeze_string_literal: true

# Keep track of submission uploaded due to task submission
class TiiActionUploadSubmission < TiiAction
  delegate :status_sym, :status, :submission_id, :submitted_by_user, :task, :idx, :similarity_pdf_id, :similarity_pdf_path, :filename, to: :entity

  def description
    "Upload #{self.filename} for #{self.task.student.username} from #{self.task.task_definition.abbreviation} (#{self.status} - #{self.next_step})"
  end

  # Update the status based on the response from the pdf status api or webhook
  #
  # @param [String] response - the similarity report status
  def update_from_pdf_report_status(response)
    case response
    when 'FAILED' # The report failed to be generated
      error_message = 'similarity PDF failed to be created'
    when 'SUCCESS' # Similarity report is complete
      entity.status = :similarity_pdf_requested
      entity.save
      save_progress
      download_similarity_report_pdf(skip_check: true)
      # else # pending or unknown...
    end
  end

  # Update the turn it in submission status based on the status from
  # the web hook or the API request.
  #
  # @param [TCAClient::Submission] response - the submission details
  def update_from_submission_status(response)
    # Response can be nil, if the request fails
    return if response.nil?

    case response.status
    when 'CREATED' #	Submission has been created but no file has been uploaded
      upload_file_to_tii
    when 'PROCESSING' # File contents have been uploaded and the submission is being processed
      retry_request
      # return # do nothing... wait for the webhook
    when 'COMPLETE' # Submission processing is complete
      entity.status = :submission_complete
      entity.save
      save_and_reschedule # Request the similarity report

      request_similarity_report
    when 'ERROR' # An error occurred during submission processing; see error_code for details
      save_and_log_custom_error response.error_code
      Rails.logger.error "Error with tii submission: #{id} #{self.custom_error_message}"
    end
  end

  # Update the similarity report status based on the status from
  # the web hook or the API request.
  #
  # #param [TCAClient::SimilarityMetadata] response - the similarity report status
  def update_from_similarity_status(response)
    # Response can be nil, if the request fails
    return if response.nil?

    case response.status
    # when 'PROCESSING' # Similarity report is being generated
    #   return
    when 'COMPLETE' # Similarity report is complete
      entity.overall_match_percentage = response.overall_match_percentage

      flag = response.overall_match_percentage.present? && response.overall_match_percentage.to_i > task.tii_match_pct(idx)

      # Update the status of the entity
      entity.update(status: flag ? :similarity_report_complete : :complete_low_similarity)

      # Create the similarity record
      TiiTaskSimilarity.find_or_initialize_by task: entity.task do |similarity|
        similarity.pct = response.overall_match_percentage
        similarity.tii_submission = entity
        similarity.flagged = flag
        similarity.save
      end

      # If we need to get the pdf report... request it
      if flag
        save_and_reschedule
        # Request the PDF if flagged
        request_similarity_report_pdf
      else
        save_and_mark_complete
      end
    end
  end

  def next_step
    case status_sym
    when :created
      "getting submission id"
    when :has_id
      "awaiting file upload"
    when :uploaded
      "awaiting submission processing"
    when :submission_complete
      "requesting similarity processing"
    when :similarity_report_requested
      "awaiting similarity report generation"
    when :similarity_report_complete
      "requesting similarity report"
    when :similarity_pdf_requested
      "awaiting similarity report"
    when :similarity_pdf_available
      "downloading similarity report"
    when "similarity_pdf_downloaded"
      "complete - report available"
    when :to_delete
      "awaiting deletion"
    when :complete_low_similarity
      "complete - low similarity"
    else
      "unknown"
    end
  end

  # Run is designed to be run in a background job, polling in
  # case of the need to retry actions. This will ensure submissions progress
  # through turn it in when web hooks fails.
  def run
    return if error? || [:deleted, :similarity_pdf_downloaded, :complete_low_similarity].include?(status)

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

    # Get the submission data
    data = tii_submission_data

    # If we don't have data, then we can't create a submission - fail as no one accepted EULA
    return false if data.blank?

    exec_tca_call "TiiSubmission #{entity.id} - fetching id" do
      # Check to ensure it is a new upload
      # Create a new Submission
      subm = TCAClient::SubmissionApi.new.create_submission(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        data
      )

      # Record the submission id
      entity.submission_id = subm.id
      entity.status = :has_id
      entity.save

      save_and_reschedule

      # If we had to indicate the eula was accepted, then we need to update the user
      unless submitted_by_user.eula_accepted_and_confirmed?
        submitted_by_user.confirm_eula_version(TurnItIn.eula_version, DateTime.now)
      end

      true
    end
  end

  # Create a turn it in submission for a task document.
  #
  # @return [TCAClient::SubmissionBase] the turn it in submission for the task
  def tii_submission_data
    result = TCAClient::SubmissionBase.new
    result.metadata = TCAClient::SubmissionBaseMetadata.new

    # Setup the task owners
    if task.group_task?
      grp = Task.group
      result.owner = "group-#{grp.id}"
      result.metadata.owners = [TurnItIn.tii_user_for_group(task.group_submission.submitter_task.student.email)]
    else
      result.owner = task.student.username
      result.metadata.owners = [TurnItIn.tii_user_for(task.student)]
    end

    # Set submission title
    result.title = "#{task.task_definition.abbreviation} - #{filename} for #{result.owner}"

    # Set submitter if not the same as the task owner
    result.submitter = submitted_by_user.username

    unless submitted_by_user.accepted_tii_eula? || (params.key?("accepted_tii_eula") && params["accepted_tii_eula"])
      save_and_log_custom_error "None of the student, tutor, or unit lead have accepted the EULA for Turnitin"
      return nil
    end

    # Add eula acceptance details to submission, if required
    if submitted_by_user.accepted_tii_eula? && !submitted_by_user.eula_accepted_and_confirmed?
      result.eula = TCAClient::EulaAcceptRequest.new(
        user_id: submitted_by_user.username,
        language: 'en-us',
        accepted_timestamp: submitted_by_user.tii_eula_date || DateTime.now,
        version: submitted_by_user.tii_eula_version || TurnItIn.eula_version
      )
    end

    result.metadata.submitter = TurnItIn.tii_user_for(submitted_by_user)
    result.owner_default_permission_set = 'LEARNER'
    result.submitter_default_permission_set = TurnItIn.tii_role_for(task, submitted_by_user)

    result.metadata.group_context = TurnItIn.create_or_get_group_context(task.unit)
    result.metadata.group = task.task_definition.create_or_get_tii_group

    result
  end

  # Upload all of the document files to the turn it in submission for a task.
  def upload_file_to_tii
    # Ensure we have a submission id and have not uploaded already
    return unless submission_id.present? && (status_sym == :has_id || status_sym == :created)
    return if error_message.present?

    error_codes = [
      { code: 413, symbol: :invalid_submission_size_too_large },
      { code: 422, symbol: :invalid_submission_size_empty },
      { code: 409, symbol: :missing_submission }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - uploading file", error_codes do
      api_instance = TCAClient::SubmissionApi.new

      api_instance.upload_submitted_file(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        'binary/octet-stream',
        "inline; filename=#{task.filename_in_zip(idx)}",
        task.read_file_from_done(idx)
      )

      entity.status = :uploaded
      entity.save
      save_and_reschedule
    end
  end

  # Get the turn it in status of the file submission
  #
  # @return [TCAClient::Submission] the submission details
  def fetch_tii_submission_status
    error_code = [
      { code: 404, symbol: :missing_submission },
      { code: 409, symbol: :generation_failed }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - fetching submission status", error_code do
      api_instance = TCAClient::SubmissionApi.new

      # Get Submission Details
      api_instance.get_submission_details(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )
    end
  end

  # Request to generate a similarity report for a task
  #
  # @return [boolean] true if the report was requested, false otherwise
  def request_similarity_report
    return unless status_sym == :submission_complete

    error_code = [
      { code: 409, symbol: :submission_not_created }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - requesting similarity report", error_code do
      add_to_index = Rails.env.production? && Doubtfire::Application.config.tii_add_submissions_to_index

      data = TCAClient::SimilarityPutRequest.new(
        indexing_settings:
          TCAClient::IndexingSettings.new(
            add_to_index: add_to_index
          ),
        generation_settings:
          TCAClient::SimilarityGenerationSettings.new(
            search_repositories: TiiActionFetchFeaturesEnabled.search_repositories,
            auto_exclude_self_matching_scope: 'GROUP_CONTEXT',
            priority: 'LOW'
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
      entity.status = :similarity_report_requested
      entity.save

      save_and_reschedule
    end
  end

  # Get the similarity report status
  #
  # @return [TCAClient::SimilarityMetadata] the similarity report status
  def fetch_tii_similarity_status
    return nil if submission_id.blank?

    exec_tca_call "TiiSubmission #{entity.id} - fetching similarity report status" do
      # Get Similarity Report Status
      TCAClient::SimilarityApi.new.get_similarity_report_results(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )
    end
  end

  # Get the pdf id for a similarity report
  #
  # @return [String] the pdf id of the similarity report
  def request_similarity_report_pdf
    return false unless status_sym == :similarity_report_complete

    error_codes = [
      { code: 404, symbol: :submission_not_found_when_creating_similarity_report }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - requesting similarity report pdf", error_codes do
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

      entity.status = :similarity_pdf_requested
      entity.similarity_pdf_id = result.id
      entity.save

      save_and_reschedule
    end
  end

  # Download the similarity pdf report.
  #
  # @param [Boolean] skip_check - skip the check to see if the report is ready
  def download_similarity_report_pdf(skip_check: false)
    return false if similarity_pdf_id.blank?
    return false unless skip_check || fetch_tii_similarity_pdf_status == 'SUCCESS'

    error_codes = [
      { code: 404, symbol: :missing_submission },
      { code: 409, symbol: :generation_failed }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - downloading similarity report pdf", error_codes do
      # GET download pdf
      result = TCAClient::SimilarityApi.new.download_similarity_report_pdf(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        similarity_pdf_id
      )

      filename = similarity_pdf_path

      if result.instance_of? Tempfile
        FileUtils.mv(result.path, filename)
      else
        file = File.new(filename, 'wb')
        begin
          file.write(result)
        ensure
          file.close
        end
      end

      entity.status = :similarity_pdf_downloaded
      entity.save
      save_and_mark_complete

      true
    end
  end

  # Get the similarity report status for a task
  #
  # @return [String] the status of the similarity report
  def fetch_tii_similarity_pdf_status
    return nil unless submission_id.present? && similarity_pdf_id.present?

    error_codes = [
      { code: 404, message: 'Submission not found in downloading similarity pdf' },
      { code: 409, message: 'PDF failed to generate, status FAILED' }
    ]

    exec_tca_call "TiiSubmission #{entity.id} - fetching similarity report pdf status", error_codes do
      # Get Similarity Report Status
      result = TCAClient::SimilarityApi.new.get_similarity_report_pdf_status(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        similarity_pdf_id
      )

      result.status
    end
  end
end
