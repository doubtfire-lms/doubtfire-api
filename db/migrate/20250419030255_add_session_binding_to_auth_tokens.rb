class AddSessionBindingToAuthTokens < ActiveRecord::Migration[7.1]
  def change
    aadd_column :auth_tokens, :last_seen_ip, :string unless column_exists?(:auth_tokens, :last_seen_ip)
    add_column :auth_tokens, :last_seen_ua, :string unless column_exists?(:auth_tokens, :last_seen_ua)

    # Use TEXT for JSON data in MySQL
    add_column :auth_tokens, :ip_history, :text unless column_exists?(:auth_tokens, :ip_history)
    add_column :auth_tokens, :suspicious_activity_detected_at, :datetime unless column_exists?(:auth_tokens, :suspicious_activity_detected_at)
    add_column :auth_tokens, :invalidation_requested_at, :datetime unless column_exists?(:auth_tokens, :invalidation_requested_at)
    add_column :auth_tokens, :last_activity_at, :datetime unless column_exists?(:auth_tokens, :last_activity_at)

    # Add index for performance
    add_index :auth_tokens, :invalidation_requested_at unless index_exists?(:auth_tokens, :invalidation_requested_at)
  end
end
