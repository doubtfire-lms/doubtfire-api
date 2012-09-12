namespace :db do
  desc "Initialise the app with an empty database and only minimal users (the superuser)"
  task :update_temporal => :environment do
    
    Project.includes(:tasks).all.each do |project|
      project.update_attribute(:progress, project.calculate_progress)
      project.update_attribute(:status,   project.calculate_status)
    end

  end
end