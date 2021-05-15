#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  # def warden
  #   puts ENV['warden'].inspect
  #   env['warden']
  # end

  module_function

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?
    # Variable to store auth_token if available
    token_with_value = nil
    # Check warden -- authenticate using DB or LDAP etc.
    # return true if warden.authenticated?
    auth_param = headers['Auth-Token'] || params['auth_token']
    user_param = headers['Username'] || params['username']

    # Check for valid auth token  and username in request header
    user = current_user

    # Authenticate from header or params
    if auth_param.present? && user_param.present? && user.present?
      # Get the list of tokens for a user
      token = user.token_for_text?(auth_param)
    end

    # Check user by token
    if user.present? && token.present?
      logger.info("Authenticated #{user.username} from #{request.ip}") if token.auth_token_expiry > Time.zone.now
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
    User.find_by_username(headers['Username']) || User.find_by_username(params['username'])
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
        type:     'String',
        in:       'header',
        desc:     'Username'
      }
      options[:params]['Auth_Token'] = {
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
