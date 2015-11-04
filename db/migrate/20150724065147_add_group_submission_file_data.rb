class AddGroupSubmissionFileData < ActiveRecord::Migration
  def change
  	# need the task id to 
  	add_column :group_submissions, :task_definition_id, :integer
  end
end
