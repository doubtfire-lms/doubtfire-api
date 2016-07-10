# Enforce test environment
ENV["RAILS_ENV"] = "test"

namespace :test do
  desc "Setup the test database for minitest"
  task setup: [:environment, 'db:setup', 'db:migrate'] do
    require 'helpers/database_populator'
    dbpop = DatabasePopulator.new
    dbpop.generate_user_roles()
    dbpop.generate_users()
    dbpop.generate_units()
  end
end
