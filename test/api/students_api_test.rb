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
    #data_to_get = add_auth_token(unit_id: 1)
    #create new user
    #newUser = User.new
    newUser = FactoryGirl.build(:user)
    newUnit = FactoryGirl.build(:unit)

    # The get that we will be testing.
    get with_auth_token '/api/students/?unit_id=1'
    response = last_response_body

    assert_equal 200, last_response.status
  end

  def test_get_students_without_authentication
    #data_to_get = add_auth_token(unit_id: 1)
    #create new user
    #newUser = User.new
    newUser = FactoryGirl.build(:user)
    newUnit = FactoryGirl.build(:unit)

    # The get that we will be testing.
    get '/api/students/?unit_id=1'
    assert_equal 419, last_response.status
  end

  def test_get_students_without_parameters
    #data_to_get = add_auth_token(unit_id: 1)
    #create new user
    #newUser = User.new
    newUser = FactoryGirl.build(:user)
    newUnit = FactoryGirl.build(:unit)

    # The get that we will be testing.
    get with_auth_token '/api/students/'
    assert_equal 400, last_response.status
  end
end
