require 'grape'
require 'json/jwt'
require 'onelogin/ruby-saml'
require 'entities/user_entity'

#
# Provides the authentication API for Doubtfire.
# Users can sign in via email and password and receive an auth token
# that can be used with other API calls.
#
class AuthenticationApi < Grape::API
  helpers LogHelper
  helpers AuthenticationHelpers

  #
  # Sign in - only mounted if AAF auth is NOT used
  #
  if !AuthenticationHelpers.aaf_auth? && !AuthenticationHelpers.saml_auth?
    desc 'Sign in'
    params do
      requires :username, type: String, desc: 'User username'
      requires :password, type: String, desc: 'User\'s password'
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    post '/auth' do
      username = params[:username]
      password = params[:password]
      remember = params[:remember]
      logger.info "Authenticate #{username} from #{request.ip}"

      # Truncate the 's' from sXXX for Swinburne auth
      truncate_s_match = (username =~ /^[Ss]\d{6,10}([Xx]|\d)$/)
      username[0] = '' if !truncate_s_match.nil? && truncate_s_match.zero?

      # No provided credentials
      if username.nil? || password.nil?
        error!({ error: 'The request must contain the user username and password.' }, 400)
      end

      # User lookup
      username = username.downcase
      institution_email_domain = Doubtfire::Application.config.institution[:email_domain]
      user = User.find_or_create_by(username: username) do |new_user|
        new_user.first_name = 'First Name'
        new_user.last_name  = 'Surname'
        new_user.email      = "#{username}@#{institution_email_domain}"
        new_user.nickname   = 'Nickname'
        new_user.role_id    = Role.student.id
        new_user.login_id   = username
      end

      # Try to authenticate
      unless user.authenticate?(password)
        error!({ error: 'Invalid email or password.' }, 401)
        return
      end

      # Create user if they are a new record
      if user.new_record?
        user.encrypted_password = BCrypt::Password.create('password')

        unless user.valid?
          error!(error: 'There was an error creating your account in Doubtfire. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'Doubtfire administrators.')
        end
        user.save
      end

      logger.info "Login #{username} from #{request.ip}"

      # Return user details
      present :user, user, with: Entities::UserEntity
      present :auth_token, user.generate_authentication_token!(remember).authentication_token
    end
  end

  #
  # Local registration - only mounted if external auth is NOT used
  #
  if !AuthenticationHelpers.aaf_auth? && !AuthenticationHelpers.saml_auth?
    desc 'Register a new user'
    params do
      requires :username, type: String, desc: 'Desired username'
      requires :email, type: String, desc: 'Email address'
      requires :first_name, type: String, desc: 'First name'
      requires :last_name, type: String, desc: 'Last name'
      requires :password, type: String, desc: 'Password'
    end
    post '/auth/register' do
      username = params[:username].downcase
      email = params[:email].downcase

      error!({ error: 'Registration not permitted.' }, 403) unless Doubtfire::Application.config.auth_method == :local

      user = User.find_by(username: username) || User.find_by(email: email)
      error!({ error: 'User already exists.' }, 409) if user

      role_id = Role.student.id
      user = User.new(
        username: username,
        email: email,
        first_name: params[:first_name],
        last_name: params[:last_name],
        nickname: params[:first_name],
        role_id: role_id,
        login_id: username
      )
      user.encrypted_password = BCrypt::Password.create(params[:password])

      unless user.valid?
        error!({ error: 'Invalid user details.', details: user.errors.full_messages }, 422)
      end
      user.save!

      present :user, user, with: Entities::UserEntity
      present :auth_token, user.generate_authentication_token!(false).authentication_token
    end
  end

  #
  # Password reset (request + confirm) - only for local database auth
  #
  if !AuthenticationHelpers.aaf_auth? && !AuthenticationHelpers.saml_auth?
    desc 'Request password reset'
    params do
      requires :email, type: String, desc: 'Account email address'
    end
    post '/auth/password/forgot' do
      email = params[:email].downcase
      user = User.find_by(email: email)

      # Always respond 200 to avoid user enumeration
      if user
        user.reset_password_token = SecureRandom.hex(24)
        user.reset_password_sent_at = Time.zone.now
        user.save(validate: false)

        # In production we would deliver an email. For development, log the token.
        logger.info("Password reset requested for #{user.username} from #{request.ip}. Token: #{Rails.env.development? ? user.reset_password_token : '[hidden]'}")
      end

      present nil
    end

    desc 'Confirm password reset'
    params do
      requires :token, type: String, desc: 'Reset password token'
      requires :password, type: String, desc: 'New password'
    end
    post '/auth/password/reset' do
      token = params[:token]
      user = User.find_by(reset_password_token: token)

      error!({ error: 'Invalid or expired token.' }, 400) unless user && user.reset_password_sent_at && user.reset_password_sent_at > 2.hours.ago

      user.encrypted_password = BCrypt::Password.create(params[:password])
      user.reset_password_token = nil
      user.reset_password_sent_at = nil
      user.save!

      present nil
    end
  end

  #
  # Change password for authenticated user
  #
  desc 'Change password for current user',
       {
         headers:
         {
           "username" => { description: "User username", required: true },
           "auth_token" => { description: "Auth token", required: true }
         }
       }
  params do
    requires :current_password, type: String, desc: 'Current password'
    requires :new_password, type: String, desc: 'New password'
  end
  put '/auth/password' do
    # Require a valid session
    error!({ error: 'Unauthenticated.' }, 419) unless authenticated?

    user = current_user

    # Only applicable for local auth
    if AuthenticationHelpers.aaf_auth? || AuthenticationHelpers.saml_auth? || AuthenticationHelpers.ldap_auth?
      error!({ error: 'Password change not supported for external authentication.' }, 400)
    end

    # Verify current password
    unless user.authenticate?(params[:current_password])
      error!({ error: 'Current password is incorrect.' }, 400)
    end

    user.encrypted_password = BCrypt::Password.create(params[:new_password])
    user.save!

    present nil
  end

  #
  # AAF JWT callback - only mounted if AAF SAML is used
  # This isn't really a JWT, we will treat it as if it's a SAML response
  #
  if AuthenticationHelpers.saml_auth?
    desc 'SAML2.0 auth'
    params do
      requires :SAMLResponse, type: String, desc: 'Data provided for further processing.'
    end
    post '/auth/jwt' do
      response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], allowed_clock_drift: 1.second,
                                                                         settings: AuthenticationHelpers.saml_settings)

      # We validate the SAML Response and check if the user already exists in the system
      return error!({ error: 'Invalid SAML response.' }, 401) unless response.is_valid?

      attributes = response.attributes

      login_id = response.name_id || response.nameid
      email = login_id

      logger.info "Authenticate #{email} from #{request.ip}"

      # Lookup using login_id if it exists
      # Lookup using email otherwise and set login_id
      # Otherwise create new
      user = User.find_by(login_id: login_id) ||
             User.find_by_username(email[/(.*)@/, 1]) ||
             User.find_by(email: email) ||
             User.find_or_create_by(login_id: login_id) do |new_user|
               role_response = attributes.fetch(/role/) || attributes.fetch(/userRole/)
               role = role_response.include?('Staff') ? Role.tutor.id : Role.student.id
               first_name = (attributes.fetch(/givenname/) || attributes.fetch(/cn/)).capitalize
               last_name = attributes.fetch(/surname/).capitalize
               username = email.split('@').first
               # Some institutions may provide givenname and surname, others
               # may only provide common name which we will use as first name
               new_user.first_name = first_name
               new_user.last_name  = last_name
               new_user.email      = email
               new_user.username   = username
               new_user.nickname   = first_name
               new_user.role_id    = role
             end

      # Set login id + username if not yet specified
      user.login_id = login_id if user.login_id.nil?
      user.username = username if user.username.nil?

      # Try and save the user once authenticated if new
      if user.new_record?
        user.encrypted_password = BCrypt::Password.create(SecureRandom.hex(32))
        unless user.valid?
          error!(error: 'There was an error creating your account in Doubtfire. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'Doubtfire administrators.')
        end
        user.save
      end

      # Generate a temporary auth_token for future requests
      onetime_token = user.generate_temporary_authentication_token!

      logger.info "Redirecting #{user.username} from #{request.ip}"

      # Must redirect to the front-end after sign in
      host = Doubtfire::Application.config.institution[:host]
      unless host.starts_with?('http')
        protocol = Rails.env.development? ? 'http' : 'https'
        host = "#{protocol}://#{host}"
      end
      redirect "#{host}/#/sign_in?authToken=#{onetime_token.authentication_token}&username=#{user.username}"
    end
  end

  #
  # AAF JWT callback - only mounted if AAF auth is used
  #
  if AuthenticationHelpers.aaf_auth?
    desc 'AAF Rapid Connect JWT callback'
    params do
      requires :assertion, type: String, desc: 'Data provided for further processing.'
    end
    post '/auth/jwt' do
      jws = params[:assertion]
      error!({ error: 'JWS was not found in request.' }, 500) unless jws

      # Decode JWS
      jwt = User.decode_jws(jws)
      error!({ error: 'Invalid JWS.' }, 500) unless jwt

      # User lookup via unique login id
      attrs = jwt['https://aaf.edu.au/attributes']
      login_id = jwt[:sub]
      email = attrs[:mail]

      logger.info "Authenticate #{email} from #{request.ip}"

      # Lookup using login_id if it exists
      # Lookup using email otherwise and set login_id
      # Otherwise create new
      user = User.find_by(login_id: login_id) ||
             User.find_by_username(email[/(.*)@/, 1]) ||
             User.find_by(email: email) ||
             User.find_or_create_by(login_id: login_id) do |new_user|
               role = Role.aaf_affiliation_to_role_id(attrs[:edupersonscopedaffiliation])
               first_name = (attrs[:givenname] || attrs[:cn]).capitalize
               last_name = attrs[:surname].capitalize
               username = email.split('@').first
               # Some institutions may provide givenname and surname, others
               # may only provide common name which we will use as first name
               new_user.first_name = first_name
               new_user.last_name  = last_name
               new_user.email      = email
               new_user.username   = username
               new_user.nickname   = first_name
               new_user.role_id    = role
             end

      # Set login id + username if not yet specified
      user.login_id = login_id if user.login_id.nil?
      user.username = username if user.username.nil?

      # Try to authenticate
      return error!({ error: 'Invalid JSON web token.' }, 401) unless user.authenticate?(jws)

      # Try and save the user once authenticated if new
      if user.new_record?
        user.encrypted_password = BCrypt::Password.create(SecureRandom.hex(32))
        unless user.valid?
          error!(error: 'There was an error creating your account in Doubtfire. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'Doubtfire administrators.')
        end
        user.save
      end

      # Generate a temporary auth_token for future requests
      onetime_token = user.generate_temporary_authentication_token!

      logger.info "Redirecting #{user.username} from #{request.ip}"

      # Must redirect to the front-end after sign in
      host = Doubtfire::Application.config.institution[:host]
      unless host.starts_with?('http')
        protocol = Rails.env.development? ? 'http' : 'https'
        host = "#{protocol}://#{host}"
      end
      redirect "#{host}/#/sign_in?authToken=#{onetime_token.authentication_token}&username=#{user.username}"
    end
  end

  if AuthenticationHelpers.saml_auth? || AuthenticationHelpers.aaf_auth?
    #
    # Respond user details provided a temporary login token
    #
    desc 'Get user details from an authentication token'
    params do
      requires :username, type: String, desc: 'The user\'s username'
      requires :auth_token, type: String, desc: 'The user\'s temporary auth token'
    end
    post '/auth' do
      error!({ error: 'Invalid token.' }, 404) if params[:auth_token].nil?
      logger.info "Get user via auth_token from #{request.ip}"

      # Authenticate that the token is okay
      if authenticated?
        user = User.find_by_username(params[:username])
        token = user.token_for_text?(params[:auth_token]) unless user.nil?
        error!({ error: 'Invalid token.' }, 404) if token.nil?

        # Invalidate the token and regenrate a new one
        token.destroy!
        token = user.generate_authentication_token! true

        logger.info "Login #{params[:username]} from #{request.ip}"

        # Respond user details with new auth token
        present :user, user, with: Entities::UserEntity
        present :auth_token, token.authentication_token
      end
    end
  end

  #
  # Returns the current auth method
  #
  desc 'Authentication method configuration'
  get '/auth/method' do
    response = {
      method: Doubtfire::Application.config.auth_method
    }
    response[:redirect_to] =
      if aaf_auth?
        Doubtfire::Application.config.aaf[:redirect_url]
      elsif saml_auth?
        request = OneLogin::RubySaml::Authrequest.new
        request.create(AuthenticationHelpers.saml_settings)
      end
    present response, with: Grape::Presenters::Presenter
  end

  #
  # Returns the current auth signout URL
  #
  desc 'Authentication signout URL'
  get '/auth/signout_url' do
    response = {}
    response[:auth_signout_url] =
      if aaf_auth? && Doubtfire::Application.config.aaf[:auth_signout_url].present?
        Doubtfire::Application.config.aaf[:auth_signout_url]
      elsif saml_auth? && Doubtfire::Application.config.saml[:idp_sso_signout_url].present?
        Doubtfire::Application.config.saml[:idp_sso_signout_url]
      end
    present response, with: Grape::Presenters::Presenter
  end

  #
  # Update the expiry of an existing authentication token
  #
  desc 'Allow tokens to be updated',
       {
         headers:
         {
           "username" =>
           {
             description: "User username",
             required: true
           },
           "auth_token" =>
           {
             description: "The user's temporary auth token",
             required: true
           }
         }
       }
  params do
    optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
  end
  put '/auth' do
    token_param = headers['auth-token'] || headers['Auth-Token'] || params['Auth-Token']
    user_param = headers['username'] || headers['Username'] || params['Username'] || params['username']

    error!({ error: 'Invalid token/username.' }, 404) if token_param.nil? || user_param.nil?

    logger.info "Update token #{token_param} from #{request.ip} for #{user_param}"

    # Find user
    user = User.find_by_username(user_param)
    token = user.token_for_text?(token_param) unless user.nil?
    remember = params[:remember] || false

    # Token does not match user
    if token.nil? || user.nil? || user.username != user_param
      error!({ error: 'Invalid token.' }, 404)
    else
      token.extend_token remember if token.auth_token_expiry > Time.zone.now

      # Return extended auth token
      present :auth_token, token.authentication_token
    end
  end

  #
  # Sign out
  #
  desc 'Sign out',
       {
         headers:
         {
           "username" =>
           {
             description: "User username",
             required: true
           },
           "auth_token" =>
           {
             description: "The user's temporary auth token",
             required: true
           }
         }
       }
  delete '/auth' do
    user = User.find_by_username(headers['username'] || headers['Username'])
    token = user.token_for_text?(headers['auth-token'] || headers['Auth-Token']) unless user.nil?

    if token.present?
      logger.info "Sign out #{user.username} from #{request.ip}"
      token.destroy!
    end

    present nil
  end
end
