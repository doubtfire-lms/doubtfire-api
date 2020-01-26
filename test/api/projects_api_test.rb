require 'test_helper'
require 'date'

class ProjectsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_can_get_projects
    # Create a new dummy unit
    unit = FactoryBot.create(:unit)

    # Get a new project from unit
    new_project = unit.active_projects.first
    student = new_project.student

    # Perform Get   new_project.main_convenor_user
    get with_auth_token "/api/projects/#{new_project.id}", new_project.student
    actual_project = last_response_body
    
    # Check if the call success
    assert_equal 200, last_response.status

    # Check the returned details match as new_project
    assert_equal actual_project['project_id'], new_project.id
  end 

  def test_projects_returns_correct_number_of_projects
    user = FactoryBot.create(:user, :student, enrol_in: 2)
    get with_auth_token('/api/projects', user)
    assert_equal 2, last_response_body.count
  end

  def test_projects_returns_correct_data
    user = FactoryBot.create(:user, :student, enrol_in: 2)
    get with_auth_token('/api/projects', user)
    last_response_body.each do |data|
      project = user.projects.find(data['project_id'])
      assert project.present?, data.inspect

      assert_json_matches_model(data, project, %w(campus_id has_portfolio target_grade campus_id))
      assert_equal project.unit.name, data['unit_name'], data.inspect
      assert_equal project.unit.id, data['unit_id'], data.inspect
      assert_equal project.unit.code, data['unit_code'], data.inspect
      assert_json_matches_model(data, project.unit, %w(teaching_period_id active))
    end
  end

  def test_projects_works_with_inactive_units
    user = FactoryBot.create(:user, :student, enrol_in: 2)
    Unit.last.update(active: false)

    get with_auth_token('/api/projects', user)
    assert_equal 1, last_response_body.count

    get with_auth_token('/api/projects?include_inactive=false', user)
    assert_equal 1, last_response_body.count

    get with_auth_token('/api/projects?include_inactive=true', user)

    assert_equal 2, last_response_body.count

    last_response_body.each do |data|
      project = user.projects.find(data['project_id'])
      assert project.present?, data.inspect

      assert_json_matches_model(data, project, %w(campus_id has_portfolio target_grade campus_id))
      assert_equal project.unit.name, data['unit_name'], data.inspect
      assert_equal project.unit.id, data['unit_id'], data.inspect
      assert_equal project.unit.code, data['unit_code'], data.inspect
      assert_json_matches_model(data, project.unit, %w(teaching_period_id active))
    end
  end
end
