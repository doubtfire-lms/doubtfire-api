class AuthToken < ActiveRecord::Base

  # Auth token encryption settings
  attr_encrypted :auth_token,
    key: Doubtfire::Application.secrets.secret_key_attr,
    encode: true,
    attribute: 'authentication_token'
    
end
