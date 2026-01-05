class AddProjectTaskDeadlines < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :target_start_date, :datetime
    add_column :tasks, :target_due_date, :datetime
  end
end
