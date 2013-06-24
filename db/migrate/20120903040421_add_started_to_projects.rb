class AddStartedToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :started, :boolean

    for project in Project.includes(:tasks).all
      started = false

      if TaskEngagement.where(task_id:  project.tasks.map{|task| task.id }).count > 0
        started = true
      elsif TaskSubmission.where(task_id:  project.tasks.map{|task| task.id }).count > 0
        started = true
      end

      project.update_attribute(:started, started)
    end
  end
end