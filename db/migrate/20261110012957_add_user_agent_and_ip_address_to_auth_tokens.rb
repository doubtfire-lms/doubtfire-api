class AddUserAgentAndIpAddressToAuthTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :auth_tokens, :user_agent, :text
    add_column :auth_tokens, :ip_address, :string, limit: 45
  end
end
