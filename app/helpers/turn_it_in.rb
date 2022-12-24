# frozen_string_literal: true

# Class to interact with the Turn It In similarity api
#
class TurnItIn
  @instance = TurnItIn.new
  @x_turnitin_integration_name = 'formatif-tii'
  @x_turnitin_integration_version = '1.0'

  def self.x_turnitin_integration_name
    @x_turnitin_integration_name
  end

  def self.x_turnitin_integration_version
    @x_turnitin_integration_version
  end

  # Get the current eula - value is refreshed every 24 hours
  def self.eula_version
    eula = Rails.cache.fetch('tii.eula_version', expires_in: 24.hours) do
      @instance.fetch_eula_version
    end
    eula&.version
  end

  # Return the html for the eula
  def self.eula_html
    Rails.cache.fetch("tii.eula_html.#{TurnItIn.eula_version}", expires_in: 365.days) do
      @instance.fetch_eula_html
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

    user.update(
      tii_eula_version_confirmed: false,
      tii_eula_date: body.accepted_timestamp,
      tii_eula_version: eula_version
    )

    # Accepts a particular EULA version on behalf of an external user
    result = TCAClient::EULAApi.new.eula_version_id_accept_post(
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      body.version,
      body
    )

    user.update(tii_eula_version_confirmed: true)
    true
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to accept eula for user #{user.id} - #{e}"
    false
  end

  # Upload all of the document files to turn it in for a task
  #
  # @param task [Task] the task to upload the files for
  def self.submit(task)
    # Create a new submission for each document
    for idx in 0..task.number_of_uploaded_files.length-1 do
      if task.is_document?(idx)
        @instance.submit_document(task, idx)
      end
    end
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
      TurnItIn.x_turnitin_integration_name,
      TurnItIn.x_turnitin_integration_version,
      task.tii_submission_id,
      data
    )

    result.viewer_url
  rescue TCAClient::ApiError => e
    puts "Error when calling SimilarityApi->get_similarity_report_url: #{e}"
  end


  @eula = nil

  # Connect to tii to get the latest eula details.
  def fetch_eula_version
    api_instance = TCAClient::EULAApi.new
    api_instance.eula_version_id_get(TurnItIn.x_turnitin_integration_name, TurnItIn.x_turnitin_integration_version, 'latest')
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Failed to fetch TII EULA version #{e}"
    nil
  end

  # Connect to tii to get the eula html
  def fetch_eula_html
    api_instance = TCAClient::EULAApi.new
    api_instance.eula_version_id_view_get(TurnItIn.x_turnitin_integration_name, TurnItIn.x_turnitin_integration_version,
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

  # Create a turn it in submission for a document in the task.
  #
  # @param task [Task] the task to create the turn it in submission for. The task must not already have a turn it in submission associated with it.
  # @param idx [Integer] the index of the document to create the turn it in submission for
  # @param submitter [User] the user who is making the submission to turn it in
  # @return [Boolean] true if the submission was created, false otherwise
  def perform_submission(task, idx, submitter)
    # Check to ensure it is a new upload
    last_tii_submission_for_task = task.tii_submissions.last
    return nil unless last_tii_submission_for_task.nil? || task.file_uploaded_at > last_tii_submission_for_task.created_at

    result = TiiSubmission.create(
      task: task,
      idx: idx,
      filename: task.filename_for_upload(idx),
      submitted_at: Time.zone.now,
      status: :created,
      submitted_by_user: submitter
    )
    result.continue_process
    result
  rescue TCAClient::ApiError => e
    Doubtfire::Application.config.logger.error "Exception when performing a TII submission for task #{task.id}: #{e}"
    nil
  end
end
