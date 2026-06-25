require 'onelogin/ruby-saml'

#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  # private functions

  # Check that the user and token are valid
  # @param user_param [String] The username
  # @param auth_param [String] The authentication token
  # @param token_type [Symbol] The type of token to accept
  #
  # @returns [Symbol]
  #   :valid if the user and token are valid
  #   :token_expired if the token is expired
  def user_auth_token_type(user_param, auth_param, token_type)
    # Check for valid auth token  and username in request header
    user = current_user

    # Authenticate from header or params
    if auth_param.present? && user_param.present? && user.present?
      # Get the list of tokens for a user
      token = user.token_for_text?(auth_param, token_type)
    end

    # Check user and token
    if user.present? && token.present?
      # has the tolken not expired?
      if token.auth_token_expiry > Time.zone.now
        logger.info("Authenticated #{user.username} from #{request.ip}")
        :valid
      else
        # Token is timed out - destroy it and return error
        token.destroy!
        logger.info("Timing out token for #{user.username} from #{request.ip}")
        :token_expired
      end
    elsif token.present?
      logger.info("Error logging in for #{user_param} / #{auth_param} from #{request.ip}")
      :error
    else
      :missing_details
    end
  end

  #
  # Public functions
  #
  module_function

  def authenticated_via_refresh_token?
    auth_param = cookies['refresh_token']
    user_param = cookies['username']

    case user_auth_token_type(user_param, auth_param, :refresh_token)
    when :valid
      # Valid token and user
      true
    when :token_expired, :error, :missing_details
      # Token expired - remove cookies
      set_refresh_cookie_in_response(false)
      false
    end
  end

  # Get the user and token from the request
  # @param source [Symbol] The source of the request
  #   :header - from the request header
  #   :cookie - from the request cookie
  # @return [String, String] The username and token
  def get_user_and_token_from(source)
    if source == :header
      user_param = headers['username'] || headers['Username'] || params['username']
      auth_param = headers['auth-token'] || headers['Auth-Token'] || params['authToken'] || headers['Auth_Token'] || headers['auth_token'] || params['auth_token'] || params['Auth_Token']
    elsif source == :cookie
      user_param = cookies['username']
      auth_param = cookies['refresh_token']
    else
      # Default to nil
      user_param = nil
      auth_param = nil
    end

    [user_param, auth_param]
  end

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?(token_type = :general)
    if token_type == :refresh_token
      # Access credentials from cookie
      user_param, auth_param = get_user_and_token_from(:cookie)
    else
      user_param, auth_param = get_user_and_token_from(:header)
    end

    case user_auth_token_type(user_param, auth_param, token_type)
    when :valid
      true
    when :token_expired
      # Token is timed out - destroy it and throw error
      error!({ error: 'Authentication token expired.' }, 419)
    when :error
      # Add random delay then fail
      sleep(rand(200..399) / 1000.0)
      error!({ error: 'Could not authenticate with token. Username or Token invalid.' }, 419)
    else
      error!({ error: 'No authentication details provided. Authentication is required to access this resource.' }, 419)
    end
  end

  #
  # Get the current user either from warden or from the header
  #
  def current_user
    username = headers['username'] || headers['Username'] || params['username'] || cookies['username']
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
    metadata_file = Doubtfire::Application.config.saml[:SAML_metadata_file_path] || nil

    idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new

    if metadata_url
      settings = idp_metadata_parser.parse_remote(metadata_url)
    elsif metadata_file && File.exist?(metadata_file)
      metadata = File.read(metadata_file)
      settings = idp_metadata_parser.parse(metadata)
    else
      settings = OneLogin::RubySaml::Settings.new
      settings.idp_cert                     = Doubtfire::Application.config.saml[:idp_sso_cert]
      settings.name_identifier_format       = Doubtfire::Application.config.saml[:idp_name_identifier_format]
    end

    settings.assertion_consumer_service_url = Doubtfire::Application.config.saml[:assertion_consumer_service_url]
    settings.sp_entity_id                   = Doubtfire::Application.config.saml[:entity_id]
    settings.idp_sso_target_url             = Doubtfire::Application.config.saml[:idp_sso_target_url]
    settings.idp_slo_target_url             = Doubtfire::Application.config.saml[:idp_sso_signout_url]

    settings
  end

  #
  # Returns true if using SAML2.0 auth strategy
  #
  def saml_auth?
    Doubtfire::Application.config.auth_method == :saml
  end

  #
  # Returns true if using SAML2.0 auth strategy
  #
  def lti_enabled?
    Doubtfire::Application.config.lti_enabled == true
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

  # rubocop:disable Naming/AccessorMethodName
  def set_refresh_cookie_in_response(remember)
    # rubocop:enable Naming/AccessorMethodName

    if remember
      token = current_user.auth_tokens.where(token_type: :refresh_token).last

      # Generate a new token when the old one is absent or getting close to expiring
      if token.nil? || token.auth_token_expiry <= Time.zone.now - 12.hours
        token = current_user.generate_authentication_token!(token_type: :refresh_token)
      end

      domain = Doubtfire::Application.config.institution[:cookie_domain]

      cookies[:username] = {
        value: current_user.username,
        expires: token.auth_token_expiry,
        domain: domain,
        path: '/api/auth',
        secure: Rails.env.production?,
        same_site: true,
        httponly: true
      }

      cookies[:refresh_token] = {
        value: token.authentication_token,
        expires: token.auth_token_expiry,
        domain: domain,
        path: '/api/auth',
        secure: Rails.env.production?,
        same_site: true,
        httponly: true
      }
    else
      # Remove the cookies
      cookies.delete(:username, domain: domain, path: '/api/auth', secure: Rails.env.production?, httponly: true, same_site: true)
      cookies.delete(:refresh_token, domain: domain, path: '/api/auth', secure: Rails.env.production?, httponly: true, same_site: true)
    end
  end
end
