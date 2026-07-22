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
  helpers AuthorisationHelpers
  helpers LtiHelper

  #
  # Sign in - only mounted if AAF and SAML auth is NOT used (database auth)
  #
  if !AuthenticationHelpers.aaf_auth? && !AuthenticationHelpers.saml_auth?
    desc 'Sign in'
    params do
      requires :username, type: String, desc: 'User username'
      optional :password, type: String, desc: 'User\'s password'
      optional :auth_token, type: String, desc: 'User\'s auth token'
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    post '/auth' do
      username = params[:username]
      password = params[:password]
      auth_token = params[:auth_token]
      remember = params[:remember]
      logger.info "Authenticate #{username} from #{request.ip}"

      # No provided credentials
      if username.nil? || (password.nil? && auth_token.nil?)
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

      # Try to authenticate with password
      if password.present? && !user.authenticate?(password)
        error!({ error: 'Invalid email or password.' }, 401)
        return
      elsif auth_token.present? && !authenticated?(:login)
        error!({ error: 'Invalid user or auth token.' }, 401)
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

      user = User.find_by(username: params[:username])
      token = user&.token_for_text?(params[:auth_token], :login)

      token&.destroy!
      token = user.generate_authentication_token!
      user.record_sign_in!

      # Return user details
      present :user, user, with: Entities::UserEntity
      present :auth_token, token.authentication_token
      present :auth_token_expiry, token.auth_token_expiry
      set_refresh_cookie_in_response(remember)
    end
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

      # Get the user identification data from the SAML response
      # This includes the login_id, email and username
      user_id_data = Doubtfire::Application.config.institution_settings.map_saml_response_to_user_id(response)

      logger.info "Authenticate #{user_id_data[:email]} from #{request.ip}"

      # Lookup using login_id if it exists
      # Lookup using email otherwise and set login_id
      # Otherwise create new
      user = User.find_by(login_id: user_id_data[:login_id]) ||
             User.find_by(username: user_id_data[:username]) ||
             User.find_by(email: user_id_data[:email]) ||
             User.create do |new_user|
               # Update new user with details from the SAML response
               Doubtfire::Application.config.institution_settings.update_user_from_saml_response(
                 new_user,
                 user_id_data,
                 response
               )
             end

      # Set login id + username if not yet specified
      if user.login_id.nil? || user.username.nil?
        user.update(
          login_id: user_id_data[:login_id],
          username: user_id_data[:username]
        )
      end

      # Try and save the user once authenticated if new
      if user.new_record?
        user.encrypted_password = BCrypt::Password.create(SecureRandom.hex(32))
        unless user.valid?
          logger.error "User #{user.username} is invalid: #{user.errors.full_messages.join(', ')}"
          error!(error: 'There was an error creating your account. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'system administrators.')
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
      redirect "#{host}/sign_in?authToken=#{onetime_token.authentication_token}&username=#{user.username}"
    end

    # Saml 2 logout callback
    desc 'SAML2.0 logout callback'
    params do
      requires :SAMLResponse, type: String, desc: 'SAML logout response data.'
    end
    post '/auth/saml_logout' do
      response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], allowed_clock_drift: 1.second,
                                                                               settings: AuthenticationHelpers.saml_settings)

      # Check if the SAML response is valid - if not log an error
      unless response.is_valid?
        logger.error "Invalid SAML logout response: #{response.errors.join(', ')}"
      end

      redirect "#{host}/sign_in"
    end
  end

  #
  # LTI JWT callback - only mounted if LTI is used
  #
  if AuthenticationHelpers.lti_enabled?
    desc 'LTI1.3 auth'
    params do
      requires :ltik, type: String, desc: 'JWT provided for further processing.'
      # requires :member, type: Hash do
      #   requires :status, type: String
      #   requires :roles, type: Array[String]
      #   requires :user_id, type: String
      #   optional :lis_person_sourcedid, type: String
      #   requires :name, type: String
      #   requires :given_name, type: String
      #   requires :family_name, type: String
      #   requires :email, type: String
      #   requires :ext_user_username, type: String
      # end
    end
    post '/auth/lti' do
      token = decode_lti_token(params[:ltik])

      member = token['member']
      if member.nil?
        error!({ error: 'Invalid LTI token.' }, 400)
      end

      valid_member, missing = valid_lti_member?(member)
      unless valid_member
        error!({ error: "Missing required fields:  #{missing.join(', ')}" }, 400)
      end

      user_id_data = {
        login_id: member['ext_user_username'] || member['user_id'],
        email: member['email'],
        username: member['email']&.split('@')&.first
      }

      logger.info "Authenticate #{user_id_data[:email]} from #{request.ip}"

      # Lookup using login_id if it exists
      # Lookup using email otherwise and set login_id
      # Otherwise create new
      user = User.find_by(login_id: user_id_data[:login_id]) ||
             User.find_by(username: user_id_data[:username]) ||
             User.find_by(email: user_id_data[:email]) ||
             User.create do |new_user|
               # Update new user with details from the LTI response
               Doubtfire::Application.config.institution_settings.update_user_from_lti_response(
                 new_user,
                 user_id_data,
                 member
               )
             end

      # Set login id + username if not yet specified
      if user.login_id.nil? || user.username.nil?
        user.update(
          login_id: user_id_data[:login_id],
          username: user_id_data[:username]
        )
      end

      # Try and save the user once authenticated if new
      if user.new_record?
        user.encrypted_password = BCrypt::Password.create(SecureRandom.hex(32))
        unless user.valid?
          logger.error "User #{user.username} is invalid: #{user.errors.full_messages.join(', ')}"
          error!(error: 'There was an error linking your Lti account. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'system administrators.')
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

      logger.info "Login #{params[:username]} from #{request.ip}"

      # Respond user details with temporary auth token
      present :username, user.username
      present :auth_token, onetime_token.authentication_token
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
             User.find_by(username: email[/(.*)@/, 1]) ||
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
      redirect "#{host}/sign_in?authToken=#{onetime_token.authentication_token}&username=#{user.username}"
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
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    post '/auth' do
      error!({ error: 'Invalid authentication details.' }, 404) if params[:auth_token].blank? || params[:username].blank?
      logger.info "Get user via auth_token from #{request.ip} - #{params[:username]}"

      # Authenticate that the token is okay
      if authenticated?(:login)
        user = User.find_by(username: params[:username])
        token = user.token_for_text?(params[:auth_token], :login) unless user.nil?
        error!({ error: 'Invalid authentication details.' }, 404) if token.nil?

        # Invalidate the token and regenrate a new one
        token.destroy!
        token = user.generate_authentication_token!
        user.record_sign_in!

        logger.info "Login #{params[:username]} from #{request.ip}"

        # Respond user details with new auth token
        present :user, user, with: Entities::UserEntity
        present :auth_token, token.authentication_token
        present :auth_token_expiry, token.auth_token_expiry
        set_refresh_cookie_in_response(params[:remember])
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
  params do
    requires :remember, type: Boolean, desc: 'Retain the refresh token?', default: false
  end
  delete '/auth' do
    user = User.find_by(username: headers['username'] || headers['Username'])
    token = user&.token_for_text?(headers['auth-token'] || headers['Auth-Token'], :general)

    if token.present?
      logger.info "Sign out #{user.username} from #{request.ip}"
      token.destroy!
    end

    if cookies['refresh_token'].present? && !params[:remember]
      auth_param = cookies['refresh_token']
      user_param = cookies['username']

      user = User.find_by(username: user_param)
      token = user&.token_for_text?(auth_param, :refresh_token)
      if token.present?
        logger.info "Destroy refresh token for #{user.username} from #{request.ip}"
        token.destroy!
      end
    end

    # Remove the refresh token cookie - if remember is false
    set_refresh_cookie_in_response(false) unless params[:remember]
    present nil
  end

  desc 'Get SCORM authentication token'
  get '/auth/scorm' do
    if authenticated?(:general)
      unless authorise? current_user, User, :get_scorm_token
        error!({ error: 'You cannot get SCORM tokens' }, 403)
      end

      token = current_user.auth_tokens.find_by(token_type: :scorm)
      if token.nil? || token.auth_token_expiry <= Time.zone.now
        token&.destroy
        token = current_user.generate_scorm_authentication_token!
      end

      present :scorm_auth_token, token.authentication_token
    end
  end

  desc 'Get access token from the refresh token cookie'
  params do
    optional :delete_auth_token, type: Boolean, desc: 'Delete the auth token if also provided', default: true
  end
  post '/auth/access-token' do
    if authenticated_via_refresh_token?
      current_user.record_access!

      # Check if we have a auth token as well
      if params[:delete_auth_token]
        user_param, auth_param = get_user_and_token_from(:header)
        case user_auth_token_type(user_param, auth_param, :general)
        when :valid
          # Valid token and user
          token = current_user.token_for_text?(auth_param, :general)
          if token.present?
            token.destroy!
            logger.info "Destroying auth token for #{current_user.username} from #{request.ip}"
          end
        end
      end
      # Return user details
      token = current_user.generate_authentication_token!(token_type: :general, force_new: false)
      present :user, current_user, with: Entities::UserEntity
      present :auth_token, token.authentication_token
      present :auth_token_expiry, token.auth_token_expiry
    else
      present nil
    end
  end
end
