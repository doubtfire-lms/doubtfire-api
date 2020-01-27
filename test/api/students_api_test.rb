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
    newUnit = FactoryBot.create(:unit)

    # The get that we will be testing.
    get with_auth_token "/api/students/?unit_id=#{newUnit.id}", newUnit.main_convenor_user

    response_keys = %w(first_name last_name)

    # check the response
    last_response_body.each do | data |
      pro = Project.find(data['project_id'])
      std = pro.student
      assert_json_matches_model(data, std, response_keys)
      assert_equal data['student_email'],std['email']
    end
    assert_equal 200, last_response.status
  end

  def test_get_students_without_authentication
    # Create student user
    studentUser = FactoryBot.create(:user, :student)

    # Create unit
    newUnit = FactoryBot.create(:unit)

    # The get that we will be testing.
    get with_auth_token "/api/students/?unit_id=#{newUnit.id}",studentUser
    # check error code when an unauthorized user tries to get students' details
    assert_equal 403, last_response.status
  end

  def test_get_students_without_parameters
    # Create unit
    newUnit = FactoryBot.create(:unit)

    # The get that we will be testing without parameters.
    get with_auth_token '/api/students/', newUnit.main_convenor_user
    # check error code
    assert_equal 400, last_response.status
  end
end
