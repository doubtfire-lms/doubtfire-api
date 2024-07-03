class AddTestAttemptLinkToComment < ActiveRecord::Migration[7.1]
  def change
    # Link to corresponding SCORM test attempt for scorm comments
    add_column :task_comments, :test_attempt_id, :integer
    add_index :task_comments, :test_attempt_id
  end
end
