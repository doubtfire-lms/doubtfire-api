require 'grape'
require 'user_serializer'

module Api
  #
  # Provides the authentication API for Doubtfire.
  # Users can sign in via email and password and receive an auth token
  # that can be used with other API calls.
  #
  class Authentication < Grape::API
    helpers LogHelper

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

      # Token has expired
      if user.auth_token_expiry.nil? || user.auth_token_expiry <= DateTime.current
        # Create a new token
        user.generate_authentication_token! remember
      else
        # Extend the existing token's time
        user.extend_authentication_token remember
      end

      # Return user details
      { user: UserSerializer.new(user), auth_token: user.auth_token }
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
        if user.auth_token_expiry > DateTime.current && user.auth_token_expiry < DateTime.current + 1.hour
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
