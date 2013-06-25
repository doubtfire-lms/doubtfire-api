namespace :db do
  desc "Update the temporal attributes (i.e. progress and status) of a project"
  task update_temporal:  :environment do
    Project.includes(:tasks).all.each do |project|
      project.update_attribute(:progress, project.calculate_progress)
      project.update_attribute(:status,   project.calculate_status)
    end
  end
end