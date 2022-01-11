class SwitchToRailsEncryption < ActiveRecord::Migration[7.0]
  def change
    AuthToken.destroy_all

    remove_column :auth_tokens, :encrypted_authentication_token
    remove_column :auth_tokens, :encrypted_authentication_token_iv
    add_column :auth_tokens, :authentication_token, :string, null: false
  end
end
