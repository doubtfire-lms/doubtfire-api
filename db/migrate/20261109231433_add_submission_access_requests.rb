class AddSubmissionAccessRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :submission_opens_on, :date
    add_column :task_comments, :submission_assessed_at, :datetime
    add_column :task_comments, :submission_granted, :boolean
  end
end
