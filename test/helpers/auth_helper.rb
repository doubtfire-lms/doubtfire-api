module AuthHelper

  def get_auth_token
    user = User.first
    user.extend_authentication_token(true)
    user.auth_token
  end

  def add_auth_token(hash)
    hash[:auth_token] = get_auth_token
    hash
  end

  module_function :get_auth_token
  module_function :add_auth_token
end
