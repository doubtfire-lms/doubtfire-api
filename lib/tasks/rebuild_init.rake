namespace :db do
  desc "Dropping, migrating and initialising"
  task :rebuild_init => [:drop, :migrate, :init]
end