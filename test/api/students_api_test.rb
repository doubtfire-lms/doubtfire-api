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

    # Create unit
    newUnit = FactoryGirl.create(:unit)

    #Create campus
    newCampus = FactoryGirl.create(:campus)

    # Create student
    studentUser = FactoryGirl.create(:user, :student)

    # Assign student to the unit
    newUnit.enrol_student(studentUser, newCampus)

    # The get that we will be testing.
    get with_auth_token "/api/students/?unit_id=#{newUnit.id}"
    response_received = last_response_body

    assert_equal 200, last_response.status
  end

  def test_get_students_without_authentication
    # Create student user
    studentUser = FactoryGirl.create(:user, :student)

    # Create unit
    newUnit = FactoryGirl.create(:unit)

    #Create campus
    newCampus = FactoryGirl.create(:campus)

    # Assign student to the unit
    newUnit.enrol_student(studentUser, newCampus)

    # The get that we will be testing.
    get with_auth_token "/api/students/?unit_id=#{newUnit.id}", studentUser
    assert_equal 403, last_response.status
  end

  def test_get_students_without_parameters

    # The get that we will be testing without parameters.
    get with_auth_token '/api/students/'
    assert_equal 400, last_response.status
  end
end
