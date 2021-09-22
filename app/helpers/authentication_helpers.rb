require 'onelogin/ruby-saml'

#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  def warden
    env['warden']
  end

  module_function

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?
    user_by_token = User.find_by_auth_token(params[:auth_token]) if params && params[:auth_token]
    # Check warden -- authenticate using DB or LDAP etc.
    return true if warden.authenticated?
    # Check user by token
    if params[:auth_token] && user_by_token && user_by_token.auth_token_expiry
      # Non-expired token
      return true if user_by_token.auth_token_expiry > Time.zone.now
      # Time out this token
      error!({ error: 'Authentication token expired.' }, 419)
    else
      # Add random delay then fail
      sleep((200 + rand(200)) / 1000.0)
      error!({ error: 'Could not authenticate with token. Token invalid.' }, 419)
    end
  end

  #
  # Get the current user either from warden or from the token
  #
  def current_user
    warden.user || User.find_by_auth_token(params[:auth_token])
  end

  #
  # Add the required auth_token to each of the routes for the provided
  # Grape::API.
  #
  def add_auth_to(service)
    service.routes.each do |route|
      options = route.instance_variable_get('@options')
      next if options[:params]['auth_token']
      options[:params]['auth_token'] = {
        required: true,
        type:     'String',
        desc:     'Authentication token'
      }
    end
  end

  #
  # Returns the SAML2.0 settings object using information provided as env variables
  #
  def saml_settings
    if saml_auth?
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
