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
    # Variable to store auth_token if available
    token_with_value = nil
    # Check warden -- authenticate using DB or LDAP etc.
    return true if warden.authenticated?
    
    # Check for valid auth token  and username in request header 
    user = current_user
    if headers.present? && headers['Auth-Token'].present? && headers['Username'].present? && user.present?
      # Get the list of tokens for a user
      token = user.token_for_text?(headers['Auth-Token']) 
    end

    # Check user by token
    if user.present? && token.present?
      # Non-expired token
      return true if token.auth_token_expiry > Time.zone.now
      # Token is timed out - destroy it
      token.destroy!
      # Time out this token
      error!({ error: 'Authentication token expired.' }, 419)
    else
      # Add random delay then fail
      sleep((200 + rand(200)) / 1000.0)
      error!({ error: 'Could not authenticate with token. Username or Token invalid.' }, 419)
    end
  end

  #
  # Get the current user either from warden or from the header
  #
  def current_user
    warden.user || User.find_by_username(headers['Username'])
  end

  #
  # Add the required auth_token to each of the routes for the provided
  # Grape::API.
  #
  def add_auth_to(service)
    service.routes.each do |route|
      options = route.instance_variable_get('@options')
      next if options[:params]['auth_token']
      options[:params]['username'] = {
        required: true,
        type:     'String',
        in:       'header',
        desc:     'Username'
      }
      options[:params]['auth_token'] = {
        required: true,
        type:     'String',
        in:       'header',
        desc:     'Authentication token'
      }
    end
  end

  #
  # Returns true iff using AAF devise auth strategy
  #
  def aaf_auth?
    Doubtfire::Application.config.auth_method == :aaf
  end

  #
  # Returns true iff using LDAP devise auth strategy
  #
  def ldap_auth?
    Doubtfire::Application.config.auth_method == :ldap
  end

  #
  # Returns true iff using database devise auth strategy
  #
  def db_auth?
    Doubtfire::Application.config.auth_method == :database
  end
end
