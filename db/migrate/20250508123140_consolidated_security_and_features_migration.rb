class ConsolidatedSecurityAndFeaturesMigration < ActiveRecord::Migration[7.1]
  def up
    # ==== AUTH TOKEN SECURITY FEATURES ====

    # Add token_type to auth_tokens
    unless column_exists?(:auth_tokens, :token_type)
      add_column :auth_tokens, :token_type, :integer, null: false, default: 0
      add_index :auth_tokens, :token_type
    end

    # Add session binding columns
    unless column_exists?(:auth_tokens, :session_ip)
      add_column :auth_tokens, :session_ip, :string
    end

    unless column_exists?(:auth_tokens, :session_user_agent)
      add_column :auth_tokens, :session_user_agent, :string
    end

    # Add last seen tracking
    unless column_exists?(:auth_tokens, :last_seen_ip)
      add_column :auth_tokens, :last_seen_ip, :string
    end

    unless column_exists?(:auth_tokens, :last_seen_ua)
      add_column :auth_tokens, :last_seen_ua, :string
    end

    # Use TEXT for IP history in case of MySQL/MariaDB
    unless column_exists?(:auth_tokens, :ip_history)
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
        add_column :auth_tokens, :ip_history, :text
      else
        # PostgreSQL supports arrays
        add_column :auth_tokens, :ip_history, :string, array: true, default: []
      end
    end

    # Add security feature timestamps
    unless column_exists?(:auth_tokens, :suspicious_activity_detected_at)
      add_column :auth_tokens, :suspicious_activity_detected_at, :datetime
    end

    unless column_exists?(:auth_tokens, :invalidation_requested_at)
      add_column :auth_tokens, :invalidation_requested_at, :datetime
      add_index :auth_tokens, :invalidation_requested_at
    end

    unless column_exists?(:auth_tokens, :last_activity_at)
      add_column :auth_tokens, :last_activity_at, :datetime
    end

    # Add created_at and updated_at if they don't exist
    unless column_exists?(:auth_tokens, :created_at) && column_exists?(:auth_tokens, :updated_at)
      add_timestamps :auth_tokens, default: -> { 'CURRENT_TIMESTAMP' }, null: false
    end

    # ==== SCORM FEATURES ====

    # Add scorm_extensions column if it doesn't exist
    if column_exists?(:tasks, :scorm_extensions)
      Rails.logger.info "Column 'scorm_extensions' already exists in 'tasks' table. Skipping..."
    else
      add_column :tasks, :scorm_extensions, :integer, null: false, default: 0
    end

    # Add columns to task_definitions if they don't exist
    change_table :task_definitions do |t|
      t.boolean :scorm_enabled, default: false unless column_exists?(:task_definitions, :scorm_enabled)
      t.boolean :scorm_allow_review, default: false unless column_exists?(:task_definitions, :scorm_allow_review)
      t.boolean :scorm_bypass_test, default: false unless column_exists?(:task_definitions, :scorm_bypass_test)
      t.boolean :scorm_time_delay_enabled, default: false unless column_exists?(:task_definitions, :scorm_time_delay_enabled)
      t.integer :scorm_attempt_limit, default: 0 unless column_exists?(:task_definitions, :scorm_attempt_limit)
    end

    # ==== TASK COMMENTS POLYMORPHIC RELATIONSHIP ====

    # Enable polymorphic relationships for task comments
    remove_index :task_comments, :overseer_assessment_id if index_exists?(:task_comments, :overseer_assessment_id)

    add_column :task_comments, :commentable_type, :string unless column_exists?(:task_comments, :commentable_type)
    rename_column :task_comments, :overseer_assessment_id, :commentable_id if column_exists?(:task_comments, :overseer_assessment_id)

    if column_exists?(:task_comments, :commentable_id) && column_exists?(:task_comments, :commentable_type)
      # Using find_each to process records individually with validations
      TaskComment.where.not(commentable_id: nil).find_each do |comment|
        comment.update(commentable_type: 'OverseerAssessment')
      end
    end

    add_index :task_comments, [:commentable_type, :commentable_id] unless index_exists?(:task_comments, [:commentable_type, :commentable_id])

    # ==== TASK DEFINITION FILENAME HANDLING ====

    # Add new_column_name to task_definitions if it doesn't exist
    unless column_exists?(:task_definitions, :new_column_name)
      add_column :task_definitions, :new_column_name, :string
    end
  end

  def down
    # ==== REVERT AUTH TOKEN SECURITY FEATURES ====

    # Remove timestamps if they exist
    remove_column :auth_tokens, :created_at if column_exists?(:auth_tokens, :created_at)
    remove_column :auth_tokens, :updated_at if column_exists?(:auth_tokens, :updated_at)

    # Remove security feature timestamps
    remove_column :auth_tokens, :last_activity_at if column_exists?(:auth_tokens, :last_activity_at)

    remove_index :auth_tokens, :invalidation_requested_at if index_exists?(:auth_tokens, :invalidation_requested_at)
    remove_column :auth_tokens, :invalidation_requested_at if column_exists?(:auth_tokens, :invalidation_requested_at)

    remove_column :auth_tokens, :suspicious_activity_detected_at if column_exists?(:auth_tokens, :suspicious_activity_detected_at)

    # Remove IP history
    remove_column :auth_tokens, :ip_history if column_exists?(:auth_tokens, :ip_history)

    # Remove last seen tracking
    remove_column :auth_tokens, :last_seen_ua if column_exists?(:auth_tokens, :last_seen_ua)
    remove_column :auth_tokens, :last_seen_ip if column_exists?(:auth_tokens, :last_seen_ip)

    # Remove session binding columns
    remove_column :auth_tokens, :session_user_agent if column_exists?(:auth_tokens, :session_user_agent)
    remove_column :auth_tokens, :session_ip if column_exists?(:auth_tokens, :session_ip)

    # Remove token_type
    remove_index :auth_tokens, :token_type if index_exists?(:auth_tokens, :token_type)
    remove_column :auth_tokens, :token_type if column_exists?(:auth_tokens, :token_type)

    # ==== REVERT SCORM FEATURES ====

    # Remove scorm_extensions column if it exists
    remove_column :tasks, :scorm_extensions if column_exists?(:tasks, :scorm_extensions)

    # Remove columns from task_definitions if they exist
    if column_exists?(:task_definitions, :scorm_enabled)
      change_table :task_definitions do |t|
        t.remove :scorm_enabled, :scorm_allow_review, :scorm_bypass_test, :scorm_time_delay_enabled, :scorm_attempt_limit
      end
    end

    # ==== REVERT TASK COMMENTS POLYMORPHIC RELATIONSHIP ====

    # Revert polymorphic relationships for task comments
    remove_index :task_comments, [:commentable_type, :commentable_id] if index_exists?(:task_comments, [:commentable_type, :commentable_id])
    rename_column :task_comments, :commentable_id, :overseer_assessment_id if column_exists?(:task_comments, :commentable_id)
    remove_column :task_comments, :commentable_type if column_exists?(:task_comments, :commentable_type)

    add_index :task_comments, :overseer_assessment_id unless index_exists?(:task_comments, :overseer_assessment_id)

    # ==== REVERT TASK DEFINITION FILENAME HANDLING ====

    # Remove new_column_name from task_definitions if it exists
    remove_column :task_definitions, :new_column_name if column_exists?(:task_definitions, :new_column_name)
  end
end
