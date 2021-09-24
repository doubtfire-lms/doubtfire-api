class AddTemporalProgressStatusToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :progress, :string
    add_column :projects, :status, :string

    for project in Project.includes(:tasks).all
      project.update_attribute(:progress, project.calculate_progress)
      project.update_attribute(:status,   project.calculate_status)
    end

  end
end
