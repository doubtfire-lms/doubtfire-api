namespace :db do
  desc "Dropping, migrating and populating"
  task :rebuild => [:drop, :migrate, :populate]
end