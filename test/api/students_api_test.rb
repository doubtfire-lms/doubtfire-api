require 'test_helper'
require 'user'

class StudentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_students_with_authentication
    # Build admin user
    adminUser = FactoryGirl.build(:user, :admin)

    # The get that we will be testing.
    get with_auth_token '/api/students/?unit_id=1',adminUser
    response = last_response_body

    assert_equal 200, last_response.status
  end

  def test_get_students_without_authentication
    # Build student user
    studentUser = FactoryGirl.build(:user, :student)

    # The get that we will be testing.
    get with_auth_token '/api/students/?unit_id=1', studentUser
    assert_equal 403, last_response.status
  end

  def test_get_students_without_parameters
    # Build admin user
    adminUser = FactoryGirl.build(:user, :admin)


    # The get that we will be testing.
    get with_auth_token '/api/students/',adminUser
    assert_equal 400, last_response.status
  end
end
