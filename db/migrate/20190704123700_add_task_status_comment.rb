class AddTaskStatusComment < ActiveRecord::Migration
  def change
    add_column :task_comments, :task_status_id, :integer
  end
end
