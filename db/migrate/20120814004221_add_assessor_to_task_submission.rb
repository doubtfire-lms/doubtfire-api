class AddAssessorToTaskSubmission < ActiveRecord::Migration[4.2]
  def self.up
    add_column :task_submissions, :assessor_id, :integer
  end

  def self.down
    remove_column :task_submissions, :assessor_id, :integer
  end
end
