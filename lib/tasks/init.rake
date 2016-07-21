require_all 'lib/helpers'
namespace :db do
  desc "Initialise the app with an empty database and only minimal users (the superuser)"
  task init: [:drop, :setup, :environment] do
    dbpop = DatabasePopulator.new ENV['SCALE']
    dbpop.generate_users(Role.admin)
  end
end
