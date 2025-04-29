require 'onelogin/ruby-saml'
require 'json'

#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  module_function

  # Configuration getters for security settings
  def security_config
    Doubtfire::Application.config.session_security || {
      binding_enabled: true,
      ip_binding_strictness: :flexible,
      max_allowed_ip_changes: 3,
      suspicious_change_timeout: 5.minutes,
      token_max_lifetime: 8.hours,
      auth_enforcement_window: 15.seconds
    }
  end

  #
  # Helper method to handle ip_history JSON serialization (for MariaDB)
  #
  def ip_history_array(token)
    return [] if token.ip_history.nil?
    token.ip_history.present? ? JSON.parse(token.ip_history) : []
  rescue JSON::ParserError
    logger.error("Error parsing IP history for token #{token.id}")
    []
  end

  #
  # Helper method to update ip_history with JSON serialization
  #
  def update_ip_history(token, current_ip)
    history = ip_history_array(token)
    history << current_ip unless history.include?(current_ip)
    token.update(ip_history: history.to_json)
  end

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?(token_type = :general)
    Rails.logger.info "AUTH DEBUG: Method called for #{headers['Username'] || headers['username']} with token_type #{token_type}"
    auth_param = headers['auth-token'] || headers['Auth-Token'] || params['authToken'] || headers['Auth_Token'] || headers['auth_token'] || params['auth_token'] || params['Auth_Token']
    user_param = headers['username'] || headers['Username'] || params['username']

    # Check for valid auth token  and username in request header
    user = current_user

    # Authenticate from header or params
    if auth_param.present? && user_param.present? && user.present?
      # Get the list of tokens for a user
      token = user.token_for_text?(auth_param, token_type)
    end

    # Check user by token
    if user.present? && token.present?
      # Verify the token hasn't been marked for invalidation (logout in progress)
      if token.invalidation_requested_at.present?
        elapsed_time = Time.zone.now - token.invalidation_requested_at
        config = security_config
        if elapsed_time > config[:auth_enforcement_window]
          # The token was marked for invalidation more than AUTH_ENFORCEMENT_WINDOW ago
          # This means a logout was triggered but the request might have been dropped
          logger.warn("Blocked attempted use of token that was marked for invalidation #{elapsed_time.round(2)} seconds ago")
          token.destroy!
          error!({ error: 'Session has been terminated. Please log in again.' }, 401)
        end
      end

      # Verify the token hasn't exceeded its maximum lifetime
      config = security_config
      if token.created_at.present? && token.created_at + config[:token_max_lifetime] < Time.zone.now
        logger.info("Token exceeded maximum lifetime for #{user.username} from #{request.ip}")
        token.destroy!
        error!({ error: 'Session has exceeded maximum allowed duration. Please log in again.' }, 419)
      end

      if token.auth_token_expiry > Time.zone.now
        if token.auth_token_expiry < 5.minutes.from_now
          # Refresh the token expiry time
          token.update(auth_token_expiry: 1.hour.from_now)
          logger.info("Token refreshed for #{user.username}")
        end
        logger.info "DEBUG: Entered token expiry check for #{user.username}"

        current_ip = request.ip
        current_ua = request.user_agent

        logger.info "DEBUG: Current IP: #{current_ip}, Current UA: #{current_ua}"
        logger.info "DEBUG: Token IP: #{token.session_ip}, Token UA: #{token.session_user_agent}"

        # Handle session binding based on configured security level
        config = security_config
        if config[:binding_enabled]
          session_binding_result = verify_session_binding(token, user, current_ip, current_ua)
          return false unless session_binding_result
        else
          # If binding is disabled, just update the last seen values
          token.update(
            last_seen_ip: current_ip,
            last_seen_ua: current_ua,
            last_activity_at: Time.zone.now
          )
        end

        logger.info("Authenticated #{user.username} from #{request.ip}")
        return true
      end

      # Token is timed out - destroy it and throw error
      logger.info("Timing out token for #{user.username} from #{request.ip}")
      token.destroy!
      error!({ error: 'Authentication token expired.' }, 419)
    elsif token.present?
      logger.info("Error logging in for #{user_param} / #{auth_param} from #{request.ip}")

      # Add random delay then fail
      sleep(rand(200..399) / 1000.0)
      error!({ error: 'Could not authenticate with token. Username or Token invalid.' }, 419)
    else
      error!({ error: 'No authentication details provided. Authentication is required to access this resource.' }, 419)
    end
  end

  #
  # Verifies session binding based on configured security levels
  # Returns true if session is valid, false otherwise
  #
  def verify_session_binding(token, user, current_ip, current_ua)
    config = security_config

    # Initialize token binding data if not present
    if token.session_ip.nil? && token.session_user_agent.nil?
      # For new sessions, set the initial binding data
      token.update(
        session_ip: current_ip,
        session_user_agent: current_ua,
        last_seen_ip: current_ip,
        last_seen_ua: current_ua,
        ip_history: [current_ip].to_json,
        last_activity_at: Time.zone.now,
        suspicious_activity_detected_at: nil
      )
      logger.info("New session bound for #{user.username} from #{current_ip}")
      return true
    end

    # Check if there are any suspicious changes
    ip_changed = token.session_ip != current_ip
    ua_changed = token.session_user_agent != current_ua

    # Update most recent IP/UA and activity timestamp
    token.update(
      last_seen_ip: current_ip,
      last_seen_ua: current_ua,
      last_activity_at: Time.zone.now
    )

    # No changes detected, everything is normal
    return true unless ip_changed || ua_changed

    # If strict IP binding is enabled and IP changed, handle accordingly
    if ip_changed && config[:ip_binding_strictness] == :strict
      logger.warn("Session hijacking attempt detected for #{user.username} from #{current_ip} - strict mode")
      token.destroy!
      error!({ error: 'Security alert: Your session has been invalidated due to a location change. Please log in again.' }, 403)
      return false
    end

    # If flexible binding is enabled, check if this is the first suspicious change
    if config[:ip_binding_strictness] == :flexible
      # Track IP history for analysis
      ip_history = ip_history_array(token)

      # Add IP to history if not already present
      ip_history << current_ip unless ip_history.include?(current_ip)
      token.update(ip_history: ip_history.to_json)

      # If too many IPs are associated with this token, it's suspicious
      if ip_history.length > config[:max_allowed_ip_changes]
        logger.warn("Too many IP changes for #{user.username}, current IP: #{current_ip}")
        token.destroy!
        error!({ error: 'Security alert: Unusual account activity detected. Please log in again.' }, 403)
        return false
      end

      # If this is the first suspicious change, mark it
      if token.suspicious_activity_detected_at.nil?
        token.update(suspicious_activity_detected_at: Time.zone.now)
        logger.info("Suspicious change detected for #{user.username} from #{current_ip}, monitoring for #{config[:suspicious_change_timeout]}")
        return true
      end

      # If suspicious change was detected recently, check timeout
      if token.suspicious_activity_detected_at + config[:suspicious_change_timeout] < Time.zone.now
        # Grace period expired, require re-authentication
        logger.warn("Grace period expired for #{user.username} after suspicious changes")
        token.destroy!
        error!({ error: 'For your security, please log in again to verify your identity.' }, 403)
        return false
      end

      # Within grace period, allow access but log it
      logger.info("Allowing access during grace period for #{user.username} from #{current_ip}")
      return true
    end
    # IP binding disabled or passing all other checks
    true
  end
  #
  # Securely invalidates a user session/token
  # This method should be called at the beginning of the logout process
  #

  def invalidate_session(user, token_text = nil)
    if user.nil?
      logger.warn("Attempted to invalidate session for nil user")
      return
    end

    # Find the specific token or all tokens for the user
    tokens = if token_text.present?
               [user.token_for_text?(token_text)]
             else
               user.auth_tokens
             end
    config = security_config
    tokens.compact.each do |token|
      # Mark token for invalidation first (will be enforced by authenticated? method)
      token.update(invalidation_requested_at: Time.zone.now)

      # Then destroy it after a short delay
      # In production, this should be handled by a background job
      Thread.new do
        sleep(config[:auth_enforcement_window] * 1.5) # Wait slightly longer than the enforcement window
        token.destroy! if token.persisted?
      rescue StandardError => e
        logger.error("Error in background token destruction: #{e.message}")
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end
    end

    logger.info("Session invalidation initiated for #{user.username}")
  end

  #
  # Get the current user either from warden or from the header
  #
  def current_user
    username = headers['username'] || headers['Username'] || params['username']
    User.eager_load(:role, :auth_tokens).find_by(username: username)
  end

  #
  # Add the required auth_token to each of the routes for the provided
  # Grape::API.
  #
  def add_auth_to(service)
    service.routes.each do |route|
      options = route.instance_variable_get('@options')
      next if options[:params]['Auth_Token']

      options[:params]['Username'] = {
        required: true,
        type: 'String',
        in: 'header',
        desc: 'Username'
      }
      options[:params]['Auth_Token'] = {
        required: true,
        type: 'String',
        in: 'header',
        desc: 'Authentication token'
      }
    end
  end

  #
  # Returns the SAML2.0 settings object using information provided as env variables
  #
  def saml_settings
    return unless saml_auth?

    metadata_url = Doubtfire::Application.config.saml[:SAML_metadata_url] || nil

    if metadata_url
      idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new
      settings = idp_metadata_parser.parse_remote(metadata_url)
    else
      settings = OneLogin::RubySaml::Settings.new
      settings.idp_cert                     = Doubtfire::Application.config.saml[:idp_sso_cert]
      settings.name_identifier_format       = Doubtfire::Application.config.saml[:idp_name_identifier_format]
    end
    settings.assertion_consumer_service_url = Doubtfire::Application.config.saml[:assertion_consumer_service_url]
    settings.sp_entity_id                   = Doubtfire::Application.config.saml[:entity_id]
    settings.idp_sso_target_url             = Doubtfire::Application.config.saml[:idp_sso_target_url]
    settings.idp_slo_target_url             = Doubtfire::Application.config.saml[:idp_sso_target_url]

    settings
  end

  #
  # Returns true if using SAML2.0 auth strategy
  #
  def saml_auth?
    Doubtfire::Application.config.auth_method == :saml
  end

  #
  # Returns true if using AAF devise auth strategy
  #
  def aaf_auth?
    Doubtfire::Application.config.auth_method == :aaf
  end

  #
  # Returns true if using LDAP devise auth strategy
  #
  def ldap_auth?
    Doubtfire::Application.config.auth_method == :ldap
  end

  #
  # Returns true if using database devise auth strategy
  #
  def db_auth?
    Doubtfire::Application.config.auth_method == :database
  end
  # Explicitly declare these functions as module functions
  module_function :security_config
  module_function :ip_history_array
  module_function :update_ip_history
  module_function :verify_session_binding
  module_function :invalidate_session
end
