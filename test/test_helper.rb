ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/rails"

# Consider setting MT_NO_EXPECTATIONS to not add expectations to Object.
# ENV["MT_NO_EXPECTATIONS"] = true

require 'simplecov'
SimpleCov.start 'rails'
# Setup RAILS_ENV as test and expand config for test environment

raise 'You cannot run this in production' if Rails.env.production?
require File.expand_path('../../config/environment', __FILE__)

# Check if we're connected to the test DB
begin
  ApplicationRecord.connection
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

require 'webmock/minitest'

# Require all test helpers
require_all 'test/helpers'
require 'rails/test_help'
require 'database_cleaner'

# require 'database_cleaner'
class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Inclide FactoryBot
  include FactoryBot::Syntax::Methods

  # Run tests in parallel with specified workers
  # parallelize(workers: :number_of_processors)

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
    Rails.cache.clear
  end

  # Add more helper methods to be used by all tests here...
  require_all 'test/helpers'

  # extend MiniTest::Spec::DSL

  # register_spec_type self do |desc|
  #   desc < ApplicationRecord if desc_is_a? Class
  # end
end
