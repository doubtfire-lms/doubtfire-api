require 'onelogin/ruby-saml'

#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  module_function

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?
    auth_param = headers['auth-token'] || headers['Auth-Token'] || params['authToken'] || headers['Auth_Token'] || headers['auth_token'] || params['auth_token'] || params['Auth_Token']
    user_param = headers['username'] || headers['Username'] || params['username']

    # Check for valid auth token  and username in request header
    user = current_user

    # Authenticate from header or params
    if auth_param.present? && user_param.present? && user.present?
      # Get the list of tokens for a user
      token = user.token_for_text?(auth_param)
    end

    # Check user by token
    if user.present? && token.present?
      if token.auth_token_expiry > Time.zone.now
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
  # Get the current user either from warden or from the header
  #
  def current_user
    username = headers['username'] || headers['Username'] || params['username']
    User.eager_load(:role, :auth_tokens).find_by_username(username)
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
end
