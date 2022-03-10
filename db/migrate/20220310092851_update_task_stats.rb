class UpdateTaskStats < ActiveRecord::Migration[7.0]
  def change
    # Migrate all projects data - update the task stats
    Project.all.each do |project|
      project.update_task_stats
    end
  end
end
