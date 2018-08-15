module TestHelpers
  #
  # Authentication test helper
  #
  module AuthHelper
    #
    # Gets an auth token for the provided user
    #
    def auth_token(user = User.first)
      user.extend_authentication_token(true)
      user.auth_token
    end

    #
    # Adds an authentication token to the hash data or string URL
    # This prevents us from having to keep adding the :auth_token
    # key to any GET/POST/PUT etc. data that is needed
    #
    def add_auth_token(data, user = User.first)
      # Passed in an id instead of a user model? Find the user model from User.find
      user = User.find(user) if user.is_a? Integer
      if data.is_a? Hash
        data[:auth_token] = auth_token user
      elsif data.is_a? String
        # If we have a question mark, we need to add a query paramater using &
        # otherwise use ?
        data << (data.include?('?') ? '&' : '?') << "auth_token=#{auth_token user}"
      end
      data
    end

    #
    # Alias for above for nicer usage (e.g., get with_auth_token "http://")
    #
    def with_auth_token(data, user = User.first)
      add_auth_token data, user
    end

    module_function :auth_token
    module_function :add_auth_token
    module_function :with_auth_token
  end
end
