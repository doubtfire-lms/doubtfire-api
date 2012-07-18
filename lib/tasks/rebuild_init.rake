namespace :db do
  desc "Dropping, migrating and initialising"
  task :rebuild => [:drop, :migrate, :init]
end