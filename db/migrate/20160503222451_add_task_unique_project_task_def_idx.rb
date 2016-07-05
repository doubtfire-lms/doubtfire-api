class AddTaskUniqueProjectTaskDefIdx < ActiveRecord::Migration
  def change
    add_index :tasks, [:project_id, :task_definition_id], :unique => true, :name => "tasks_uniq_proj_task_def"
  end
end
