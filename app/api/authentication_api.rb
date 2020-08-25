require 'grape'
require 'user_serializer'
require 'json/jwt'
require 'logger'

module Api
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
    unless AuthenticationHelpers.aaf_auth?
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
          return
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

        # Return user details
        { 
          user: UserSerializer.new(user),
          auth_token: user.generate_authentication_token!(remember).authentication_token
        }
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

        # Identity provider must match the one set in the configuration -- this
        # prevents an identity provider from a different institution from trying
        # to log into this instance of Doubtfire
        referer = request.referer
        error!({ error: 'This URL must be referered by AAF.' }, 500) unless referer
        request_idp = referer.split('entityID=').last
        unless request_idp == Doubtfire::Application.config.aaf[:identity_provider_url]
          logger.error "Rejecting authentication from #{referer} idp #{request_idp}"
          error!({ error: 'This request was not verified by the correct identity provider.' }, 500)
        end

        # Decode JWS
        jwt = User.decode_jws(jws)
        error!({ error: 'Invalid JWS.' }, 500) unless jwt

        # User lookup via unique login id
        attrs = jwt['https://aaf.edu.au/attributes']
        login_id = jwt[:sub]
        email = attrs[:mail]

        # Lookup using login_id if it exists
        # Lookup using email otherwise and set login_id
        # Otherwise create new
        user = User.find_by(login_id: login_id) ||
               User.find_by_username(email[/(.*)@/,1]) ||
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
          user.encrypted_password = BCrypt::Password.create('password')

          unless user.valid?
            error!(error: 'There was an error creating your account in Doubtfire. ' \
                          'Please get in contact with your unit convenor or the ' \
                          'Doubtfire administrators.')
          end
          user.save
        end

        # Generate a temporary auth_token for future requests
        user.generate_temporary_authentication_token!

        # Must redirect to the front-end after sign in
        protocol = Rails.env.development? ? 'http' : 'https'
        host = Rails.env.development? ? 'localhost:8000' : Doubtfire::Application.config.institution[:host]
        redirect "#{protocol}://#{host}/#sign_in?authToken=#{user.auth_token}"
      end

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

          # Respond user details with new auth token
          {
            user: UserSerializer.new(user),
            auth_token: token.authentication_token
          }
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
      response[:redirect_to] = Doubtfire::Application.config.aaf[:redirect_url] if aaf_auth?
      response
    end

    #
    # Returns the current auth signout URL
    #
    desc 'Authentication signout URL'
    get '/auth/signout_url' do
      response = {}
      response[:auth_signout_url] = Doubtfire::Application.config.aaf[:auth_signout_url] if aaf_auth? && Doubtfire::Application.config.aaf[:auth_signout_url].present?
      response
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
          description: "The user\'s temporary auth token",
          required: true
        }
      }
    }
    params do
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    put '/auth' do
      #UPDATE - Following print statements to check for headers
      puts request.headers.inspect
      puts "Parameters: Username: #{params[:username]} Password: #{params[:password]}"
      
      error!({ error: 'Invalid token' }, 404) if headers['Auth-Token'].nil?
      logger.info "Update token #{headers['Auth-Token']} from #{request.ip}"

# UPDATE
      logger = Logger.new(Rails.root.to_s + '/log/AuthAPI.log' )
      logger.info "Update token #{headers['Auth-Token']} username #{headers['Username']}"
      
      
      # Find user
      user = User.find_by_username(headers['Username'])
      token = user.token_for_text?(headers['Auth-Token']) unless user.nil?
      remember = params[:remember] || false

      # Token does not match user
      if token.nil? || user.nil? || user.username != headers['Username']
        error!({ error: 'Invalid token.' }, 404)
      else
        if token.auth_token_expiry > Time.zone.now
          token.extend_token remember
        end
        
        # Return extended auth token
        { 
          auth_token: token.authentication_token 
        }
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
          description: "The user\'s temporary auth token",
          required: true
        }
      }
    }
    delete '/auth' do
      user = User.find_by_username(headers['Username'])
      token = user.token_for_text?(headers['Auth-Token']) unless user.nil?

      if token.present?
        logger.info "Sign out #{user.username} from #{request.ip}"
        token.destroy!
      end

      nil
    end
  end
end
