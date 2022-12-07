# frozen_string_literal: true

# Class to interact with the Turn It In similarity api
#
class TurnItIn
  @instance = TurnItIn.new
  @x_turnitin_integration_name = 'formatif-tii'
  @x_turnitin_integration_version = '1.0'

  # Get the current eula - value is refreshed every 24 hours
  def self.eula_version
    eula = Rails.cache.fetch('tii.eula_version', expires_in: 24.hours) do
      @instance.fetch_eula_version
    end
    @instance.eula&.version
  end

  # Return the html for the eula
  def self.eula_html
    Rails.cache.fetch("tii.eula_html.#{TurnItIn.eula_version}", expires_in: 365.days) do
      fetch_eula_html
    end
  end

  # Accept the provided eula version
  #
  # @param user [User] the user to accept the eula on behalf of
  # @param eula_version [String] the version of the eula to accept
  # @return [Boolean] true if the eula was accepted, false otherwise
  def self.accept_eula(user, eula_version = TurnItIn.eula_version)
    body = TCAClient::EulaAcceptRequest.new(
      user_id: user.username,
      language: 'en-us',
      accepted_timestamp: DateTime.now,
      version: eula_version
    )

    # Accepts a particular EULA version on behalf of an external user
    result = TCAClient::EULAApi.new.eula_version_id_accept_post(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      body.version,
      body
    )

    user.update(tii_eula_version: result)
    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to accept eula for user #{user.id} - #{e}"
    false
  end

  # Delete the turn it in submission for a task
  #
  # @param task [Task] the task to delete the turn it in submission for
  # @return [Boolean] true if the submission was deleted, false otherwise
  def self.delete_submission(task)
    TCAClient::SubmissionApi.new.delete_submission(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id
    )

    Doubtfire::Application.config.logger.info "Deleted tii submission #{task.tii_submission_id} for task #{task.id}"

    if task.group_task?
      task.group_submission.tasks.update_all(tii_submission_id: nil)
    else
      task.update(tii_submission_id: nil)
    end

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Exception when deleting TII submission for task #{task.id}: #{e}"
    false
  end

  # Create a turn it in submission for a task.
  #
  # @param task [Task] the task to create the turn it in submission for. The task must not already have a turn it in submission associated with it.
  # @param submitter [User] the user who is making the submission to turn it in
  # @return [Boolean] true if the submission was created, false otherwise
  def self.perform_submission(task, submitter)
    return false unless task.tii_submission_id.nil?

    # Create a new Submission
    result = TCAClient::SubmissionApi.new.create_submission(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      TurnItIn.create_submission_for(task, submitter)
    )

    # Record the submission id
    if task.group_task?
      task.group_submission.tasks.update_all(tii_submission_id: result.id)
    else
      task.update(tii_submission_id: result.id)
    end

    @instance.upload_task_to_submission(task)

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Exception when performing a TII submission for task #{task.id}: #{e}"
    false
  end

  # Create a turn it in submission for a task.
  #
  # @param task [Task] the task to create the turn it in submission for.
  # @param submitter [User] the user who is making the submission to turn it in
  # @return [TCAClient::SubmissionBase] the turn it in submission for the task
  def self.create_submission_for(task, submitter)
    result = TCAClient::SubmissionBase.new
    result.metadata = TCAClient::SubmissionBaseMetadata.new

    # Setup the task owners
    if task.group_task?
      result.owner = task.group_submission.submitter_task.student.username
      result.metadata.owners = task.group_submission.tasks.map { |t| @instance.tii_user_for(t.student) }
    else
      result.owner = task.student.username
      result.metadata.owners = [@instance.tii_user_for(task.student)]
    end

    # Set submission title
    result.title = "#{task.task_definition.abbreviation} for #{result.owner}"

    # Set submitter if not the same as the task owner
    result.submitter = submitter.username
    result.metadata.submitter = @instance.tii_user_for(submitter)
    result.owner_default_permission_set = 'LEARNER'
    result.submitter_default_permission_set = @instance.tii_role_for(task, submitter)

    result.metadata.group = @instance.create_or_get_group(task.task_definition)
    result.metadata.group_context = @instance.create_or_get_group_context(task.unit)

    result
  end

  # Get the turn it in status of a task
  #
  # @param [Task] task - the task to get the status for
  # @return [TCAClient::Submission] the submission details
  def self.task_status(task)
    return nil unless task.tii_submission_id.present?

    api_instance = TCAClient::SubmissionApi.new
    id = task.tii_submission_id # String | The Submission ID (returned upon a successful POST to /submissions)

    begin
      # Get Submission Details
      api_instance.get_submiddion_details(@x_turnitin_integration_name, @x_turnitin_integration_version, id)
    rescue TCAClient::ApiError => e
      Doubtfire::Application.config.logger.error "Error when calling SubmissionApi->get_submission_details: #{e}"
      nil
    end
  end

  # Request to generate a similarity report for a task
  #
  # @param [Task] task - the task to generate the report for
  # @return [boolean] true if the report was requested, false otherwise
  def self.request_similarity_report(task)
    return false unless task.tii_submission_id.present?

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
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id,
      data
    )

    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Error when calling SubmissionApi->request_similarity_report: #{e}"
    false
  end

  def self.get_similarity_report_url(task, user)
    return nil unless task.tii_submission_id.present?

    data = TCAClient::SimilarityViewerUrlSettings.new(
      viewer_user_id: user.username,
      locale: 'en-US',
      viewer_default_permission_set: @instance.tii_role_for(task, user)
    )

    # Returns a URL to access Cloud Viewer
    result = TCAClient::SimilarityApi.new.get_similarity_report_url(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id,
      data
    )

    result.viewer_url
  rescue TCAClient::ApiError => e
    puts "Error when calling SimilarityApi->get_similarity_report_url: #{e}"
  end

  def self.get_and_process_similarity_data_for(task)
    return false unless task.tii_submission_id.present?

  end

  # Get the similarity report status for a task
  #
  # @param [Task] task - the task to get the status for
  # @return [String] the status of the similarity report
  def self.similarity_report_status(task, pdf_id = @instance.similarity_report_pdf_id(task))
    return nil unless task.tii_submission_id.present?

    # Get Similarity Report Status
    result = TCAClient::SimilarityApi.new.get_similarity_report_pdf_status(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id,
      pdf_id
    )

    result.status
  rescue TCAClient::ApiError => e
    puts "Error when calling SimilarityApi->get_similarity_report_status: #{e}"
  end

  def self.download_similarity_report_pdf(task)
    return false unless task.tii_submission_id.present?

    pdf_id = @instance.similarity_report_pdf_id(task)

    status = similarity_report_status(task, pdf_id)
    return false unless status == 'SUCCESS'

    # GET download pdf
    result = TCAClient::SimilarityApi.new.download_similarity_report_pdf(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id,
      pdf_id
    )

    path = FileHelper.student_work_dir(:plagarism, task)
    filename = File.join(path, FileHelper.sanitized_filename("#{task.id}-tii.pdf"))
    file = File.new(filename, 'wb')
    begin
      file.write(result)
    ensure
      file.close
    end
  rescue TCAClient::ApiError => e
    puts "Error when calling SimilarityApi->download_similarity_report_pdf: #{e}"
  end

  private

  # Connect to tii to get the latest eula details.
  def fetch_eula_version
    api_instance = TCAClient::EULAApi.new
    api_instance.eula_version_id_get(@x_turnitin_integration_name, @x_turnitin_integration_version, 'latest')
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to fetch TII EULA version #{e}"
    nil
  end

  # Connect to tii to get the eula html
  def fetch_eula_html
    api_instance = TCAClient::EULAApi.new
    api_instance.eula_version_id_view_get(@x_turnitin_integration_name, @x_turnitin_integration_version,
                                          TurnItIn.eula_version)
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to fetch TII EULA version #{e}"
    nil
  end

    # Create or get the group context for a unit. The "group context" is the Turn It In equivalent of a unit.
  #
  # @param unit [Unit] the unit to create or get the group context for
  # @return [TCAClient::GroupContext] the group context for the unit
  def create_or_get_group_context(unit)
    unless unit.tii_group_context_id.present?
      unit.tii_group_context_id = SecureRandom.uuid
      unit.save
    end

    TCAClient::GroupContext.new(
      id: unit.tii_group_context_id,
      name: unit.detailed_name,
      owners: unit.staff.where(role_id: Role.convenor_id).map { |ur| ur.user.username }
    )
  end

  # Create or get the group for a task definition. The "group" is the Turn It In equivalent of an assignment.
  #
  # @param task_def [TaskDefinition] the task definition to create or get the group for
  # @return [TCAClient::Group] the group for the task definition
  def create_or_get_group(task_def)
    unless task_def.tii_group_id.present?
      task_def.tii_group_id = SecureRandom.uuid
      task_def.save
    end

    TCAClient::Group.new(
      id: task_def.tii_group_id,
      name: task_def.detailed_name,
      type: 'FOLDER'
    )
  end

  # Get the turn it in user for a user
  #
  # @param user [User] the user to get the turn it in user for
  # @return [TCAClient::Users] the turn it in user for the user
  def tii_user_for(user)
    TCAClient::Users.new(
      id: user.username,
      family_name: user.last_name,
      given_name: user.first_name,
      email: user.email
    )
  end

  def tii_role_for(task, user)
    user_role = task.role_for(user)
    if [:tutor].include?(user_role) || (user_role.nil? && user.role_id == Role.admin_id)
      'INSTRUCTOR'
    else
      'LEARNER'
    end
  end

  # Get the pdf id for a similarity report
  #
  # @param [Task] task - the task to get the pdf id for
  # @return [String] the pdf id of the similarity report
  def similarity_report_pdf_id(task)
    return nil unless task.tii_submission_id.present?

    generate_similarity_pdf = TCAClient::GenerateSimilarityPDF.new(
      locale: 'en-US'
    )

    # Get Similarity Report Status
    result = TCAClient::SimilarityApi.new.request_similarity_report_pdf(
      @x_turnitin_integration_name,
      @x_turnitin_integration_version,
      task.tii_submission_id,
      generate_similarity_pdf
    )

    result.id
  rescue TCAClient::ApiError => e
    puts "Error when calling SimilarityApi->get_similarity_report_status: #{e}"
    nil
  end

  # Upload all of the document files to the turn it in submission for a task.
  #
  # @param task [Task] the task to upload the document files for
  def upload_task_to_submission(task)
    return false unless task.tii_submission_id.present?

    api_instance = TCAClient::SubmissionApi.new

    for idx in 0..task.number_of_uploaded_files
      if task.is_document?(idx)
        result = api_instance.upload_submitted_file(
          @x_turnitin_integration_name,
          @x_turnitin_integration_version,
          task.tii_submission_id,
          'binary/octet-stream',
          "inline; filename=#{task.filename_in_zip(idx)}",
          task.read_file_from_done(idx)
        )
      end
    end
  end

end
