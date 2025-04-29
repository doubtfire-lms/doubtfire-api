class AddTimestampsToAuthTokens < ActiveRecord::Migration[7.1]
  def change
    add_timestamps :auth_tokens, default: -> { 'CURRENT_TIMESTAMP' }, null: false
  end
end
