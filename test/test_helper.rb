ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/rails"

# Consider setting MT_NO_EXPECTATIONS to not add expectations to Object.
# ENV["MT_NO_EXPECTATIONS"] = true

# Check if we're connected to the test DB
begin
  ActiveRecord::Base.connection
rescue ActiveRecord::NoDatabaseError
  # No database... try setting up
  puts 'No test database has been setup! Setting first-time up...'
  require 'rake'
  Rake::Task['test:setup'].invoke
  puts 'First-time test setup complete. Please re-run `rake test` again.'
  exit
end

# Require minitest extensions
require 'minitest/rails'
require 'minitest/pride'

# require 'database_cleaner'
class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Run tests in parallel with specified workers
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Silence deprecation warnings
  ActiveSupport::Deprecation.silenced = true

  # Support rollback of db changes after all tests
  DatabaseCleaner.strategy = :transaction

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  # Add more helper methods to be used by all tests here...
  require_all 'test/helpers'

  # extend MiniTest::Spec::DSL

  # register_spec_type self do |desc|
  #   desc < ActiveRecord::Base if desc_is_a? Class
  # end
end
