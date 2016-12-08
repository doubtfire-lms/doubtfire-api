require 'grape'
require 'user_serializer'
require 'json/jwt'

module Api
  #
  # Provides the authentication API for Doubtfire.
  # Users can sign in via email and password and receive an auth token
  # that can be used with other API calls.
  #
  class Authentication < Grape::API
    helpers LogHelper
    helpers AuthenticationHelpers

    #
    # Sign in
    #
    desc 'Sign in'
    params do
      requires :username, type: String, desc: 'User username'
      requires :password, type: String, desc: 'User\'s password'
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    post '/auth' do
      # If AAF, redirect to AAF redirection URL -- this endpoint is useless
      if aaf_auth?
        return { redirect_to: Doubtfire::Application.config.aaf[:redirect_url] }
      end

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
      end

      # Redirect acain_student or acain_tutor
      acain_match = username =~ /^acain_.*$/
      user.username = 'acain' if !acain_match.nil? && acain_match.zero?

      # Try to authenticate
      unless user.authenticate?(password)
        error!({ error: 'Invalid email or password.' }, 401)
        return
      end

      # Restore username if acain_...
      user.username = username if !acain_match.nil? && acain_match.zero?

      # Create user if they are a new record
      if user.new_record?
        user.password = 'password'
        user.encrypted_password = BCrypt::Password.create('password')
        unless user.valid?
          error!(error: 'There was an error creating your account in Doubtfire. ' \
                        'Please get in contact with your unit convenor or the ' \
                        'Doubtfire administrators.')
        end
        user.save
      end

      user.extend_authentication_token(remember)

      # Return user details
      { user: UserSerializer.new(user), auth_token: user.auth_token }
    end

    #
    # AAF JWT callback
    #
    if AuthenticationHelpers.aaf_auth?
      desc 'AAF Rapid Connect JWT callback'
      params do
        requires :assertion, type: String, desc: 'Data provided for further processing.'
      end
      post '/auth/jwt' do
        jws = params[:assertion]
        error!({ error: 'JWS was not found in request' }, 500) unless jws

        # Decode JWS
        jwt = User.decode_jws(jws)
        error!({ error: 'Invalid JWS' }, 500) unless jwt

        # User lookup via unique login id
        # attrs = jwt['https://aaf.edu.au/attributes']
        # email = attrs[:mail]
        # user = User.find_or_create_by(username: username) do |new_user|
        #   new_user.first_name = 'First Name'
        #   new_user.last_name  = 'Surname'
        #   new_user.email      = "#{username}@#{institution_email_domain}"
        #   new_user.nickname   = 'Nickname'
        #   new_user.role_id    = Role.student.id
        # end

        # Try to authenticate
        unless user.authenticate?(jws)
          error!({ error: 'Invalid JSON web token.' }, 401)
          return
        end

      end
    end

    #
    # Update token
    #
    desc 'Allow tokens to be updated'
    params do
      requires :username, type: String,  desc: 'User username'
      optional :remember, type: Boolean, desc: 'User has requested to remember login', default: false
    end
    put '/auth/:auth_token' do
      error!({ error: 'Invalid token.' }, 404) if params[:auth_token].nil?
      logger.info "Update token #{params[:username]} from #{request.ip}"

      # Find user
      user = User.find_by_auth_token(params[:auth_token])
      remember = params[:remember] || false

      # Token does not match user
      if user.nil? || user.username != params[:username]
        error!({ error: 'Invalid token.' }, 404)
      else
        if user.auth_token_expiry > Time.zone.now && user.auth_token_expiry < Time.zone.now + 1.hour
          user.reset_authentication_token!
          user.generate_authentication_token! remember
        end
        # Return extended auth token
        { auth_token: user.auth_token }
      end
    end

    #
    # Sign out
    #
    desc 'Sign out'
    delete '/auth/:auth_token' do
      user = User.find_by_auth_token(params[:auth_token])

      if user
        logger.info "Sign out #{user.username} from #{request.ip}"
        user.reset_authentication_token!
      end

      nil
    end
  end
end
