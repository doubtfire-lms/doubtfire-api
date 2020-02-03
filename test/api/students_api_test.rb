require 'test_helper'

class StudentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_students_with_authorization
    # Create unit
    newUnit = FactoryBot.create(:unit)

    # The get that we will be testing.
    get with_auth_token "/api/students/?unit_id=#{newUnit.id}", newUnit.main_convenor_user

    # check returning number of students
    assert_equal newUnit.active_projects.all.count,last_response_body.count

    # check the response
    response_keys = %w(first_name last_name)   
    last_response_body.each do | data |
      pro = newUnit.active_projects.find(data['project_id'])
      std = pro.student
      assert_json_matches_model(data, std, response_keys)
      assert_equal data['student_email'],std['email']
    end
    assert_equal 200, last_response.status
  end

  def test_get_students_without_authorization
    # Create unit
    newUnit = FactoryBot.create(:unit)

    # Obtain a student from unit
    studentUser = newUnit.active_projects.first.student

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
