# frozen_string_literal: true

# Class to interact with the Turn It In similarity api
#
class TurnItIn
  @instance = TurnItIn.new

  # rubocop:disable Style/ClassVars
  @@x_turnitin_integration_name = 'formatif-tii'
  @@x_turnitin_integration_version = '1.0'
  @@global_error = nil
  @@delay_call_until = nil

  cattr_reader :x_turnitin_integration_name, :x_turnitin_integration_version

  def self.load_config(config)
    config.tii_enabled = ENV['TII_ENABLED'].present? && ENV['TII_ENABLED'].to_s.downcase != "false" && ENV['TII_ENABLED'].to_i != 0

    if config.tii_enabled
      # Turn-it-in TII configuration
      require 'tca_client'

      # Setup authorization
      TCAClient.configure do |tii_config|
        # Configure API key authorization: api_key
        tii_config.api_key['api_key'] = ENV.fetch('TCA_API_KEY', nil)
        # Uncomment the following line to set a prefix for the API key, e.g. 'Bearer' (defaults to nil)
        tii_config.api_key_prefix['api_key'] = 'Bearer'
        tii_config.host = ENV.fetch('TCA_HOST', nil)
        tii_config.base_path = 'api/v1'
        tii_config.server_index = nil
        require_relative '../../config/environments/doubtfire_logger'
        tii_config.logger = DoubtfireLogger.logger
      end
    end
  end

  # A global error indicates that tii is not configured correctly or a change in the
  # environment requires that the configuration is updated
  def self.global_error
    return nil unless Doubtfire::Application.config.tii_enabled

    Rails.cache.fetch("tii.global_error") do
      @@global_error
    end
  end

  # Update the global error, when present this will block calls to tii until resolved
  def self.global_error=(value)
    return unless Doubtfire::Application.config.tii_enabled

    @@global_error = value

    if value.present?
      Rails.cache.write("tii.global_error", value)
    else
      Rails.cache.delete("tii.global_error")
    end
  end

  # Indicates if there is a global error that indicates that things should not call tii until resolved
  def self.global_error?
    return false unless Doubtfire::Application.config.tii_enabled

    Rails.cache.exist?("tii.global_error") || @@global_error.present?
  end

  # Indicates that tii can be called, that it is configured and there are no global errors
  def self.functional?
    Doubtfire::Application.config.tii_enabled && !TurnItIn.global_error?
  end

  # Indicates that the service is rate limited
  def self.rate_limited?
    @@delay_call_until.present? && DateTime.now < @@delay_call_until
  end

  def self.reset_rate_limit
    @@delay_call_until = nil
  end

  # Run a call to TCA, handling any errors that occur
  #
  # @param action [String] the action that is being performed
  # @param block [Proc] the block that will be called to perform the call
  def self.exec_tca_call(action, &block)
    unless TurnItIn.functional?
      Doubtfire::Application.config.logger.error "TII failed. #{action}. Turn It In not functional"
      raise TCAClient::ApiError, code: 0, message: "Turn It In not functional"
    end
    if TurnItIn.rate_limited?
      Doubtfire::Application.config.logger.error "TII failed. #{action}. Turn It In is rate limited"
      raise TCAClient::ApiError, code: 429, message: "Turn It In rate limited"
    end

    block.call
  rescue TCAClient::ApiError => e
    handle_tii_error(action, e)
    raise
  end

  # Handle an error raised by a TCA call
  #
  # @param action [String] the action that was being performed
  # @param error [TCAClient::ApiError] the error that was raised
  def self.handle_tii_error(action, error)
    Doubtfire::Application.config.logger.error "TII failed. #{action}. #{error}"

    case error.code
    when 429 # rate limit
      @@delay_call_until = DateTime.now + 1.minute
    when 403 # forbidden, issue with authentication... do not attempt more tii requests
      TurnItIn.global_error = [403, error.message]
    end
  end

  # rubocop:enable Style/ClassVars

  # Get the current eula - value is refreshed every 24 hours
  def self.eula_version
    return nil unless Doubtfire::Application.config.tii_enabled
    eula = Rails.cache.fetch('tii.eula_version', expires_in: 24.hours) do
      @instance.fetch_eula_version
    end
    eula&.version
  end

  # Return the html for the eula
  def self.eula_html
    return nil unless Doubtfire::Application.config.tii_enabled

    Rails.cache.fetch("tii.eula_html.#{TurnItIn.eula_version}", expires_in: 365.days) do
      @instance.fetch_eula_html
    end
  end

  # Accept the provided eula version
  #
  # @param user [User] the user to accept the eula on behalf of
  # @param eula_version [String] the version of the eula to accept
  # @return [Boolean] true if the eula was accepted, false otherwise
  def self.accept_eula(user)
    user.update(last_eula_retry: DateTime.now)
    TurnItIn.exec_tca_call "accept eula for user #{user.id}" do
      body = TCAClient::EulaAcceptRequest.new(
        user_id: user.username,
        language: 'en-us',
        accepted_timestamp: user.tii_eula_date || DateTime.now,
        version: user.tii_eula_version || TurnItIn.eula_version
      )

      if body.version.nil?
        Doubtfire::Application.logger.error "TII eula version is nil, user #{id} cannot accept eula"
        return false
      end

      # Accepts a particular EULA version on behalf of an external user
      TCAClient::EULAApi.new.eula_version_id_accept_post(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        body.version,
        body
      )

      user.update(tii_eula_version_confirmed: true)
      true
    end
  rescue TCAClient::ApiError => e
    user.update(tii_eula_retry: false) if [400, 404].include?(e.code)

    # Errors:
    # 400	Request is malformed or missing required data
    # 403	Not Properly Authenticated
    # 429	Request has been rejected due to rate limiting
    # 500	An unexpected error was encountered
    #
    # 404	The EULA version in the given language was not found
    # 400	The EULA version attempting to be accepted is not valid
    # 400	The EULA version was not found
    # 400	The timestamp given is invalid
    # 400	A required field is missing

    false
  end

  @eula = nil

  # Connect to tii to get the latest eula details.
  def fetch_eula_version
    TurnItIn.exec_tca_call 'fetch TII EULA version' do
      api_instance = TCAClient::EULAApi.new
      api_instance.eula_version_id_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        'latest'
      )
    end
  rescue TCAClient::ApiError || StandardError
    nil
  end

  # Connect to tii to get the eula html
  def fetch_eula_html
    TurnItIn.exec_tca_call 'fetch TII EULA html' do
      api_instance = TCAClient::EULAApi.new
      api_instance.eula_version_id_view_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        TurnItIn.eula_version
      )
    end
  rescue TCAClient::ApiError
    nil
  end

  # Return the url used for webhook callbacks
  def self.webhook_url
    "#{Doubtfire::Application.config.institution[:host_url]}api/tii_hook"
  end

  # List all webhooks currently registered
  def self.list_all_webhooks
    TurnItIn.exec_tca_call 'list all webhooks' do
      TCAClient::WebhookApi.new.webhooks_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version
      )
    end
  end

  # Register our webhook for all tii events
  def self.register_webhook
    data = TCAClient::WebhookWithSecret.new(
      signing_secret: ENV.fetch('TCA_SIGNING_KEY', nil),
      url: TurnItIn.webhook_url,
      event_types: %w[
        SIMILARITY_COMPLETE
        SUBMISSION_COMPLETE
        SIMILARITY_UPDATED
        PDF_STATUS
        GROUP_ATTACHMENT_COMPLETE
      ]
    ) # WebhookWithSecret |

    TurnItIn.exec_tca_call 'register webhook' do
      TCAClient::WebhookApi.new.webhooks_post(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        data
      )
    end
  end

  # Create or get the group context for a unit. The "group context" is the Turn It In equivalent of a unit.
  #
  # @param unit [Unit] the unit to create or get the group context for
  # @return [TCAClient::GroupContext] the group context for the unit
  def self.create_or_get_group_context(unit)
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
  def self.create_or_get_group(task_def)
    unless task_def.tii_group_id.present?
      task_def.tii_group_id = SecureRandom.uuid
      task_def.save
    end

    TCAClient::Group.new(
      id: task_def.tii_group_id,
      name: task_def.detailed_name,
      type: 'ASSIGNMENT'
    )
  end

  # Get the turn it in user for a user
  #
  # @param user [User] the user to get the turn it in user for
  # @return [TCAClient::Users] the turn it in user for the user
  def self.tii_user_for(user)
    TCAClient::Users.new(
      id: user.username,
      family_name: user.last_name,
      given_name: user.first_name,
      email: user.email
    )
  end

  def self.tii_role_for(task, user)
    user_role = task.role_for(user)
    if [:tutor].include?(user_role) || (user_role.nil? && user.role_id == Role.admin_id)
      'INSTRUCTOR'
    else
      'LEARNER'
    end
  end

  # Send all documents to turn it in for checking
  #
  # @param task [Task] the task to send the documents for
  def self.send_documents_to_tii(task, submitter)
    task.number_of_uploaded_files.times do |idx|
      if task.use_tii?(idx)
        @instance.send_document_to_tii(task, idx, submitter)
      end
    end
  end

  # Create a turn it in submission for a document in the task.
  #
  # @param task [Task] the task to create the turn it in submission for.
  #   The task must not already have a turn it in submission associated with it.
  # @param idx [Integer] the index of the document to create the turn it in submission for
  # @param submitter [User] the user who is making the submission to turn it in
  # @return [Boolean] true if the submission was created, false otherwise
  def send_document_to_tii(task, idx, submitter)
    # Check to ensure it is a new upload
    last_tii_submission_for_task = task.tii_submissions.where(idx: idx).last
    unless last_tii_submission_for_task.nil? || task.file_uploaded_at > last_tii_submission_for_task.created_at
      return nil
    end

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
  end

  # Send all doc and docx files from the task resources to turn it in
  # as group attachments.
  #
  # @param task_def [TaskDefinition] the task definition to send the group attachments for
  def self.send_group_attachments_to_tii(task_def)
    return unless task_def.tii_group_id.present?
    return unless task_def.has_task_resources?

    # loop through files in the task resources zip file
    Zip::File.open(task_def.task_resources) do |zip_file|
      zip_file.each do |entry|
        next unless entry.file?
        next unless entry.name.end_with?('.doc', '.docx')
        next if entry.name.include?('__MACOSX')
        next if entry.size < 50

        TiiGroupAttachment.find_or_create_from_task_definition(task_def, entry.name)
      end
    end
  end
end
