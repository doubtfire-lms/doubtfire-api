class AddInitializationVectorToAuthTokens < ActiveRecord::Migration
  def up
  	add_column	:auth_tokens, :encrypted_authentication_token_iv, null: false, :string
  end
  def down
  	remove_column	:auth_tokens, :encrypted_authentication_token_iv
  end
end
