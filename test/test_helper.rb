# Setup RAILS_ENV as test and expand config for test environment
ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)

# Check if we're connected to the test DB
begin
  ActiveRecord::Base.connection
rescue ActiveRecord::NoDatabaseError
  # No database... try setting up
  puts "No test database has been setup! Setting first-time up..."
  require 'rake'
  Rake::Task['test:setup'].invoke
  puts "First-time test setup complete. Please re-run `rake test` again."
  exit
end

# Require minitest extensions
require 'minitest/rails'
require 'minitest/pride'
require 'minitest/autorun'
require 'minitest/osx'

# Require all test helpers
require_all 'test/helpers'
require 'rails/test_help'
require 'database_cleaner'

class ActiveSupport::TestCase
  # Check if migrations are pending
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Silence deprecation warnings
  ActiveSupport::Deprecation.silenced = true

  # Support rollback of db changes after all tests
  DatabaseCleaner.strategy = :transaction

  # After setup of all test, start database cleaner to undo transactions
  def before_teardown
    super
    DatabaseCleaner.start
  end

  # After teardown
  def after_teardown
    DatabaseCleaner.clean
    super
  end

  # Add more helper methods to be used by all tests here...
end
