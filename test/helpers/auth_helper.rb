module TestHelpers
  #
  # Authentication test helper
  #
  module AuthHelper
    #
    # Gets an authentication token for User.first
    #
    def get_auth_token
      user = User.first
      user.extend_authentication_token(true)
      user.auth_token
    end

    #
    # Adds an authentication token to the hash of data provided
    # This prevents us from having to keep adding the :auth_token
    # key to any POST data that is needed
    #
    def add_auth_token(hash)
      hash[:auth_token] = get_auth_token
      hash
    end

    module_function :get_auth_token
    module_function :add_auth_token
  end
end
