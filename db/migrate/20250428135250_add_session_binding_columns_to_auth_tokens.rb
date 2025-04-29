class AddSessionBindingColumnsToAuthTokens < ActiveRecord::Migration[7.1]
  def change
    # Columns for session binding improvements
    # Only add columns if they don't already exist
    add_column :auth_tokens, :last_seen_ip, :string unless column_exists?(:auth_tokens, :last_seen_ip)
    add_column :auth_tokens, :last_seen_ua, :string unless column_exists?(:auth_tokens, :last_seen_ua)

    # For arrays, use JSON in MySQL/MariaDB since they don't support native arrays
    # Detect database type and use appropriate column type
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
      add_column :auth_tokens, :ip_history, :text unless column_exists?(:auth_tokens, :ip_history)
    else
      # PostgreSQL supports arrays
      add_column :auth_tokens, :ip_history, :string, array: true, default: [] unless column_exists?(:auth_tokens, :ip_history)
    end

    # Columns for session fixation/hijacking prevention
    add_column :auth_tokens, :suspicious_activity_detected_at, :datetime unless column_exists?(:auth_tokens, :suspicious_activity_detected_at)
    add_column :auth_tokens, :invalidation_requested_at, :datetime unless column_exists?(:auth_tokens, :invalidation_requested_at)
    add_column :auth_tokens, :last_activity_at, :datetime unless column_exists?(:auth_tokens, :last_activity_at)

    # Add index to improve query performance for token validation
    # Add index if it doesn't exist
    add_index :auth_tokens, :invalidation_requested_at unless index_exists?(:auth_tokens, :invalidation_requested_at)
  end
end
