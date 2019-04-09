require_all 'lib/helpers'
namespace :db do
  desc 'Initialise the app with an empty database and only minimal users (the superuser)'
  task init: [:skip_prod, :drop, :setup, :environment] do
    dbpop = DatabasePopulator.new ENV['SCALE']
    dbpop.generate_user_roles
    dbpop.generate_task_statuses
    dbpop.generate_users(Role.admin)
    dbpop.generate_admin
  end
end
