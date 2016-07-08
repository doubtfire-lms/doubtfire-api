ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest/rails"
require 'database_cleaner'
require "minitest/pride"
require "minitest/autorun"
require "minitest/osx"

# Require help with all tests
require 'helpers/auth_helper'
require 'helpers/assert_helper'

class ActiveSupport::TestCase
    ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Silence deprecation warnings
  ActiveSupport::Deprecation.silenced = true

  # Populate the database ONCE on each start
  system 'RAILS_ENV=test rake db:init_test_data'

  # Support rollback of db changes after all tests
  DatabaseCleaner.strategy = :transaction

  # After setup of all test, start database cleaner
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
