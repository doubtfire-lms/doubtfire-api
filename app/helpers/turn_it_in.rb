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
    config.tii_enabled = ENV['TII_ENABLED'].present? && (ENV['TII_ENABLED'].to_s.downcase == "true" || ENV['TII_ENABLED'].to_i == 1)

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

  # Launch the tii background jobs
  def self.launch_tii(with_webhooks: true)
    TiiRegisterWebHookJob.perform_async if with_webhooks

    (TiiActionFetchFeaturesEnabled.last || TiiActionFetchFeaturesEnabled.create).perform

    (TiiActionFetchEula.last || TiiActionFetchEula.create).perform
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

    unless Rails.cache.exist?('tii.eula_version')
      action = TiiActionFetchEula.last || TiiActionFetchEula.create
      action.perform
    end

    eula = Rails.cache.fetch('tii.eula_version')

    eula&.version
  end

  # Return the html for the eula
  def self.eula_html
    return nil unless Doubtfire::Application.config.tii_enabled

    Rails.cache.fetch("tii.eula_html.#{TurnItIn.eula_version}")
  end

  # Return the url used for webhook callbacks
  def self.webhook_url
    "#{Doubtfire::Application.config.institution[:host_url]}api/tii_hook"
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

  private

  def logger
    Doubtfire::Application.config.logger
  end
end
