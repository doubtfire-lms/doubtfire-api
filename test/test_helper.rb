require 'simplecov'
SimpleCov.start 'rails'

# Setup RAILS_ENV as test and expand config for test environment
ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
# require File.expand_path('../../config/environment', __FILE__)
require "rails/test_help"

raise 'You cannot run this in production' if Rails.env.production?

# Consider setting MT_NO_EXPECTATIONS to not add expectations to Object.
# ENV["MT_NO_EXPECTATIONS"] = true

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

# Setup sidekiq
require 'sidekiq/testing'
Sidekiq::Testing.fake!

# Require minitest extensions
require 'minitest/pride'
require 'minitest/around'

require 'webmock/minitest'

# Require all test helpers
require_all 'test/helpers'
require 'rails/test_help'
require 'database_cleaner/active_record'

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_all_pending!

  extend Minitest::Spec::DSL

  # Inclide FactoryBot
  include FactoryBot::Syntax::Methods

  # Add more helper methods to be used by all tests here...
  require_all 'test/helpers'

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

  setup do
    DatabaseCleaner.start
    WebMock.reset!
    Sidekiq::Testing.fake!

    # Ensure turn it in states is cleared
    TurnItIn.reset_rate_limit
    TurnItIn.global_error = nil

    TestHelpers::TiiTestHelper.setup_tii_eula
    TestHelpers::TiiTestHelper.setup_tii_features_enabled

    @last_unit_id = Unit.last.id
  end

  teardown do
    Rails.cache.clear
    Sidekiq::Job.clear_all

    # Destroy any units there were created so that files are cleaned up
    Unit.where("id > :last_unit_id", last_unit_id: @last_unit_id).destroy_all

    DatabaseCleaner.clean
    Faker::UniqueGenerator.clear
  end
end
