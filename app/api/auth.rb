require 'grape'

module Api

  #
  # Provides the authentication API for Doubtfire.
  # Users can sign in via email and password and receive an auth token
  # that can be used with other API calls.
  #
  class Auth < Grape::API
    
    desc "Sign in" 
    params do
      requires :email, type: String, desc: 'User email address'
      requires :password, type: String, desc: 'User''s password'
    end
    post '/auth' do
      email = params[:email]
      password = params[:password]

      if email.nil? or password.nil?
        error!({"error" => "The request must contain the user email and password."}, 400)
        return
      end

      user = User.find_by_email(email.downcase)

      if user.nil?
        # logger.info("User #{email} failed signin, user cannot be found.")
        error!({"error" => "Invalid email or password."}, 401)
        return
      end

      user.ensure_authentication_token!

      if not user.valid_password?(password)
             
        error!({"error" => "Invalid email or password."}, 401)
      else
          user.auth_token_expiry = DateTime.now + 30
          user.save

          { user: user, auth_token: user.authentication_token }
      end
    end

    desc "Sign out"
    delete '/auth/:auth_token' do
      user=User.find_by_authentication_token(params[:auth_token])
      if user.nil?
        # logger.info("Token not found.")
        error!({"error" => "Invalid token."}, 404)
      else
        user.reset_authentication_token!
        params[:id]
      end
    end
  end
end
