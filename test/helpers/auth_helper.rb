module TestHelpers
  #
  # Authentication test helper
  #
  module AuthHelper
    #
    # Gets the Rails application need to call the api
    #
    def app
      Rails.application
    end

    #
    # Gets an auth token for the provided user
    #
    def auth_token(user = User.first, token_type = :general)
      token = user.valid_auth_tokens.where(token_type: token_type).first
      return token.authentication_token unless token.nil?

      return user.generate_authentication_token!(token_type: token_type).authentication_token
    end

    #
    # Adds an authentication token and Username to the header
    # This prevents us from having to keep adding the :auth_token
    # key to any GET/POST/PUT etc. data that is needed
    #
    def add_auth_header_for(user: User.first, username: nil, auth_token: nil)
      if username.present?
        header 'username', username
      else
        header 'username', user.username
      end

      if auth_token.present?
        header 'auth_token', auth_token
      else
        header 'auth_token', auth_token(user)
      end
    end

    def clear_auth_header
      header 'username', nil
      header 'auth_token', nil
    end

    module_function :auth_token
    module_function :add_auth_header_for
    module_function :clear_auth_header
  end
end
