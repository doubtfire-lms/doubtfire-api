class AddSubmissionOpensAtToTaskDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :submission_opens_at, :date
  end
end
