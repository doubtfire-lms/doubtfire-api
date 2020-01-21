require 'simplecov'
SimpleCov.start 'rails'
# Setup RAILS_ENV as test and expand config for test environment
ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../config/environment', __FILE__)

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
require 'minitest/around'

# Require all test helpers
require_all 'test/helpers'
require 'rails/test_help'
require 'database_cleaner'

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Inclide FactoryBot
  include FactoryBot::Syntax::Methods

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Silence deprecation warnings
  ActiveSupport::Deprecation.silenced = true

  # Support rollback of db changes after all tests
  DatabaseCleaner.strategy = :transaction

  def setup
    Faker::UniqueGenerator.clear
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  # Add more helper methods to be used by all tests here...
  require_all 'test/helpers'

  extend MiniTest::Spec::DSL

  register_spec_type self do |desc|
    desc < ActiveRecord::Base if desc_is_a? Class
  end
end
