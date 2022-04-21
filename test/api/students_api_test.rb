require 'test_helper'

class StudentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_students_with_authorization
    # Create a unit
    newUnit = FactoryBot.create(:unit, with_students: true)

    # Add username and auth_token to Header
    add_auth_header_for(user: newUnit.main_convenor_user)

    # The get that we will be testing.
    get "/api/students/?unit_id=#{newUnit.id}"

    # check returning number of students
    assert_equal newUnit.active_projects.all.count,last_response_body.count

    # check the response
    response_keys = %w(first_name last_name)
    last_response_body.each do | data |
      pro = newUnit.active_projects.find(data['project_id'])
      std = pro.student
      assert_json_matches_model(std, data, response_keys)
      assert_equal data['student_email'],std['email']
    end
    assert_equal 200, last_response.status
  end

  def test_get_students_without_authorization
    # Create unit
    newUnit = FactoryBot.create(:unit, with_students: true)

    # Obtain a student from unit
    studentUser = newUnit.active_projects.first.student

    # Add username and auth_token to Header
    add_auth_header_for(user: studentUser)

    # The get that we will be testing.
    get "/api/students/?unit_id=#{newUnit.id}"
    # check error code when an unauthorized user tries to get students' details
    assert_equal 403, last_response.status
  end

  def test_get_students_without_parameters
    # Create unit
    newUnit = FactoryBot.create(:unit)

    # Add username and auth_token to Header
    add_auth_header_for(user: newUnit.main_convenor_user)

    # The get that we will be testing without parameters.
    get '/api/students/'

    # check error code
    assert_equal 400, last_response.status
  end

  def test_students_tutorial_enrolments
    # Create unit
    unit = FactoryBot.create(:unit, with_students: true, stream_count: 2, campus_count: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # The get that we will be testing without parameters.
    get "/api/students/?unit_id=#{unit.id}"

    assert_equal 200, last_response.status
    assert_equal unit.active_projects.count, last_response_body.count

    last_response_body.each do |data|
      assert_equal 2, data['tutorial_enrolments'].count, data.inspect
      data['tutorial_enrolments'].each do |data_ts|
        project = unit.active_projects.find(data['project_id'])
        stream_abbr = data_ts['stream_abbr']
        tutorial_id = data_ts['tutorial_id']

        stream = unit.tutorial_streams.find_by!(abbreviation: stream_abbr)

        tutorial = project.tutorial_for_stream(stream)

        if tutorial.present?
          assert tutorial_id.present?
          assert_equal unit.tutorials.find(tutorial_id), project.tutorial_for_stream(stream), data_ts.inspect
        else
          assert_nil tutorial_id
        end
      end
    end
  end
end
