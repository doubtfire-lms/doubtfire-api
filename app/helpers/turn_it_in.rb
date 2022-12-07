#
# Class to interact with the Turn It In similarity api
#
class TurnItIn
  @@x_turnitin_integration_name = 'formatif-tii'
  @@x_turnitin_integration_version = '1.0'

  # Get the current eula - value is refreshed every 24 hours
  def self.eula_version
    eula = Rails.cache.fetch("tii.eula_version", expires_in: 24.hours) do
      self.fetch_eula_version
    end
    eula.version unless eula.nil?
  end

  def self.eula_html()
    result = Rails.cache.fetch("tii.eula_html.#{TurnItIn.eula_version}", expires_in: 365.days) do
      self.fetch_eula_html
    end
    result
  end

  def self.accept_eula(user, eula_version)
    begin
      api_instance = TCAClient::EULAApi.new

      body = TCAClient::EulaAcceptRequest.new # EulaAcceptRequest
      body.user_id = user.username
      body.language = 'en-us'
      body.accepted_timestamp = DateTime.now
      body.version = eula_version

      version_id = body.version # String | The EULA version ID (or `latest`)

      #Accepts a particular EULA version on behalf of an external user
      result = api_instance.eula_version_id_accept_post(@@x_turnitin_integration_name, @@x_turnitin_integration_version, version_id, body)

      user.update(tii_eula_version: eula_version)
      true
    rescue TCAClient::ApiError => e
      Doubtfire::Application.config.logger.error "Failed to accept eula for user #{user.id} - #{e}"
      false
    end
  end

  def self.create_or_get_group_contect(unit)
    result = TCAClient::GroupContext.new

    unless unit.tii_group_context_id.present?
      unit.tii_group_context_id = SecureRandom.uuid
      unit.save
    end

    result.id = unit.tii_group_context_id
    result.name = unit.detailed_name
    result.owners = unit.staff.where(role_id: Role.convenor_id).map{|ur| ur.user.username}
    result
  end

  def self.create_or_get_group(task_def)
    result = TCAClient::Group.new

    unless task_def.tii_group_id.present?
      task_def.tii_group_id = SecureRandom.uuid
      task_def.save
    end

    result.id = task_def.tii_group_id
    result.name = task_def.detailed_name
    result.type = "ASSIGNMENT"
    result
  end

  def self.tii_user_for(user)
    result = TCAClient::Users.new
    result.id = user.username
    result.family_name = user.last_name
    result.given_name = user.first_name
    result.email = user.email
    result
  end

  def self.delete_submission(task)
    api_instance = TCAClient::SubmissionApi.new

    begin
      #Delete an existing submission
      result = api_instance.delete_submission(@@x_turnitin_integration_name, @@x_turnitin_integration_version, task.tii_submission_id)

      if task.group_task?
        task.group_submission.tasks.update_all(tii_submission_id: nil)
      else
        task.update(tii_submission_id: nil)
      end

      true
    rescue TCAClient::ApiError => e
      puts "Exception when calling SubmissionApi->create_submission: #{e}"
      false
    end
  end

  def self.perform_submission(task, submitter)
    return false unless task.tii_submission_id.nil?
    api_instance = TCAClient::SubmissionApi.new

    begin
      #Create a new Submission
      body = TurnItIn.create_submission_for(task, submitter)
      result = api_instance.create_submission(@@x_turnitin_integration_name, @@x_turnitin_integration_version, body)

      if task.group_task?
        task.group_submission.tasks.update_all(tii_submission_id: result.id)
      else
        task.update(tii_submission_id: result.id)
      end

      true
    rescue TCAClient::ApiError => e
      puts "Exception when calling SubmissionApi->create_submission: #{e}"
      false
    end
  end

  def self.upload_task_to_submission(task)
    api_instance = TCAClient::SubmissionApi.new

    for idx in 0..task.number_of_uploaded_files
      if task.is_document?(idx)
        result = api_instance.upload_submitted_file(@@x_turnitin_integration_name, @@x_turnitin_integration_version, task.tii_submission_id, "binary/octet-stream", "inline; filename;'#{task.filename_in_zip(idx)}'", task.read_file_from_done(idx))
      end
    end
  end

  def self.create_submission_for(task, submitter)
    result = TCAClient::SubmissionBase.new
    result.metadata = TCAClient::SubmissionBaseMetadata.new

    # Setup the task owners
    if task.group_task?
      result.owner = task.group_submission.submitter_task.student.username
      result.metadata.owners = task.group_submission.tasks.map{|t| TurnItIn.tii_user_for(t.student)}
    else
      result.owner = task.student.username
      result.metadata.owners = [TurnItIn.tii_user_for(task.student)]
    end

    # Set submission title
    result.title = "#{task.task_definition.abbreviation} for #{result.owner}"

    # Set submitter if not the same as the task owner
    result.submitter = submitter.username
    result.metadata.submitter = TurnItIn.tii_user_for(submitter)
    #
    result.owner_default_permission_set = 'LEARNER'
    submitter_role = task.role_for(submitter)
    result.submitter_default_permission_set = if [:tutor].include?(submitter_role) || (submitter_role.nil? && submitter.role_id == Role.admin_id) then 'INSTRUCTOR' else 'LEARNER' end

    result.metadata.group = TurnItIn.create_or_get_group(task.task_definition)
    result.metadata.group_context = TurnItIn.create_or_get_group_contect(task.unit)

    result
  end

  private

  # Connect to tii to get the latest eula details.
  def self.fetch_eula_version
    begin
      api_instance = TCAClient::EULAApi.new
      api_instance.eula_version_id_get(@@x_turnitin_integration_name, @@x_turnitin_integration_version, 'latest')
    rescue TCAClient::ApiError => e
      Doubtfire::Application.config.logger.error "Failed to fetch TII EULA version #{e}"
      nil
    end
  end

  # Connect to tii to get the eula html
  def self.fetch_eula_html
    begin
      api_instance = TCAClient::EULAApi.new
      api_instance.eula_version_id_view_get(@@x_turnitin_integration_name, @@x_turnitin_integration_version, TurnItIn.eula_version)
    rescue TCAClient::ApiError => e
      Doubtfire::Application.config.logger.error "Failed to fetch TII EULA version #{e}"
      nil
    end
  end

end
