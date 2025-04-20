class AddScormFeat < ActiveRecord::Migration[7.1]
  def up
    # Add scorm_extensions column if it doesn't exist
    unless column_exists?(:tasks, :scorm_extensions)
      add_column :tasks, :scorm_extensions, :integer, null: false, default: 0
    else
      Rails.logger.info "Column 'scorm_extensions' already exists in 'tasks' table. Skipping..."
    end

    # Add columns to task_definitions if they don't exist
    change_table :task_definitions do |t|
      t.boolean :scorm_enabled, default: false unless column_exists?(:task_definitions, :scorm_enabled)
      t.boolean :scorm_allow_review, default: false unless column_exists?(:task_definitions, :scorm_allow_review)
      t.boolean :scorm_bypass_test, default: false unless column_exists?(:task_definitions, :scorm_bypass_test)
      t.boolean :scorm_time_delay_enabled, default: false unless column_exists?(:task_definitions, :scorm_time_delay_enabled)
      t.integer :scorm_attempt_limit, default: 0 unless column_exists?(:task_definitions, :scorm_attempt_limit)
    end

    # Enable polymorphic relationships for task comments
    remove_index :task_comments, :overseer_assessment_id if index_exists?(:task_comments, :overseer_assessment_id)

    add_column :task_comments, :commentable_type, :string unless column_exists?(:task_comments, :commentable_type)
    rename_column :task_comments, :overseer_assessment_id, :commentable_id if column_exists?(:task_comments, :overseer_assessment_id)

    TaskComment.where.not(commentable_id: nil).in_batches.update_all(commentable_type: 'OverseerAssessment')

    add_index :task_comments, [:commentable_type, :commentable_id] unless index_exists?(:task_comments, [:commentable_type, :commentable_id])
  end

  def down
    # Remove scorm_extensions column if it exists
    remove_column :tasks, :scorm_extensions if column_exists?(:tasks, :scorm_extensions)

    # Remove columns from task_definitions if they exist
    change_table :task_definitions do |t|
      t.remove :scorm_enabled, :scorm_allow_review, :scorm_bypass_test, :scorm_time_delay_enabled, :scorm_attempt_limit if column_exists?(:task_definitions, :scorm_enabled)
    end

    # Revert polymorphic relationships for task comments
    remove_index :task_comments, [:commentable_type, :commentable_id] if index_exists?(:task_comments, [:commentable_type, :commentable_id])
    rename_column :task_comments, :commentable_id, :overseer_assessment_id if column_exists?(:task_comments, :commentable_id)
    remove_column :task_comments, :commentable_type if column_exists?(:task_comments, :commentable_type)

    add_index :task_comments, :overseer_assessment_id unless index_exists?(:task_comments, :overseer_assessment_id)
  end
end
