class AddScormFeat < ActiveRecord::Migration[7.1]
  def change
    # Record scorm extensions added to a task
    add_column :tasks, :scorm_extensions, :integer, null: false, default: 0

    change_table :task_definitions do |t|
      t.boolean :scorm_enabled, default: false
      t.boolean :scorm_allow_review, default: false
      t.boolean :scorm_bypass_test, default: false
      t.boolean :scorm_time_delay_enabled, default: false
      t.integer :scorm_attempt_limit, default: 0
    end

    # Enable polymorphic relationships for task comments
    remove_index :task_comments, :overseer_assessment_id

    add_column :task_comments, :commentable_type, :string
    rename_column :task_comments, :overseer_assessment_id, :commentable_id

    TaskComment.where('NOT commentable_id IS NULL').in_batches.update_all(commentable_type: 'OverseerAssessment')

    add_index :task_comments, [:commentable_type, :commentable_id]
  end
end
