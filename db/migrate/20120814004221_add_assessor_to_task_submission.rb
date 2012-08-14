class AddAssessorToTaskSubmission < ActiveRecord::Migration
  def self.up
    add_column :task_submissions, :assessor_id, :integer
  end

  def self.down
    remove_column :task_submissions, :assessor_id, :integer
  end
end
