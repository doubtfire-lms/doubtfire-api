class AddTaskStatusComment < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :task_status_id, :integer
  end
end
