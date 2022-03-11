class UpdateTaskStats < ActiveRecord::Migration[7.0]
  def change
    # Migrate all projects data - update the task stats
    Project.find_in_batches do |projects|
      projects.each { |project| project.update_task_stats }
    end
  end
end
