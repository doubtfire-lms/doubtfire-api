class AddSessionBindingToAuthTokens < ActiveRecord::Migration[7.1]
  def change
    add_column :auth_tokens, :session_ip, :string
    add_column :auth_tokens, :session_user_agent, :string
  end
end
