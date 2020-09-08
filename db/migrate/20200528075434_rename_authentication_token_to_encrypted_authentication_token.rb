class RenameAuthenticationTokenToEncryptedAuthenticationToken < ActiveRecord::Migration
  def up
  	rename_column	:auth_tokens, :authentication_token, :encrypted_authentication_token
  end
  def down
  	rename_column	:auth_tokens, :encrypted_authentication_token, :authentication_token 
  end
end
