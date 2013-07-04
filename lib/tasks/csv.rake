require 'csv'

namespace :db do
  namespace :csv do
    task :users, [:user_csv] => [:environment] do |t, args|
      User.import_from_csv(args[:user_csv])
    end

    task :users, [:user_csv] => [:environment] do |t, args|
      User.import_from_csv(args[:user_csv])
    end
  end
end