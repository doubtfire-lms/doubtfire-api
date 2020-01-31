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
    
    # A student enroll to new_project
    student = new_project.student

    # Perform Get   new_project.main_convenor_user
    get with_auth_token "/api/projects/#{new_project.id}", new_project.student
    
    # Check if the call success
    assert_equal 200, last_response.status

    # Check the returned details match as new_project
    assert_equal new_project.id, last_response_body['project_id']

    # check if the details posted match as new_project    
    response_keys = %w(unit_id campus_id enrolled) 
    project = Project.find(last_response_body['project_id'])
    assert_json_matches_model(last_response_body, project, response_keys)

    # Check if the details in the newly created project match as the new_project    
    assert_equal project['unit_id'], new_project.unit_id
    assert_equal project['campus_id'], new_project.campus_id
    assert_equal project['enrolled'], new_project.enrolled
  end 

  # PUT test
  def test_change_project_campus
    project = Project.first
    to_update = project

    # Perform update, change campus id
    put_json with_auth_token("/api/projects/#{project.id}"), { campus_id: 2 }
    
    # Check if the call success
    assert 200, last_response.status

    # Update to_update data
    to_update.reload

    # Check if the update campus id match as to_update.campus_id
    assert_equal 2, to_update.campus_id
  end

  def test_change_project_enrolled
    project = Project.first
    to_update = project

    # Perform update, change project enrolled
    put_json with_auth_token("/api/projects/#{project.id}"), { enrolled: false}
    
    # Check if the call success
    assert 200, last_response.status

    # Update to_update data
    to_update.reload

    # Check if the update enrolled match as to_update.enrolled
    assert_equal false, to_update.enrolled
  end

  def test_change_project_target_grade
    project = Project.first
    to_update = project

    # Perform update, change project target grade
    put_json with_auth_token("/api/projects/#{project.id}"), { target_grade: 1 }
    
    # Check if the call success
    assert 200, last_response.status

    # Update to_update data
    to_update.reload

    # Check if the update target grade match as to_update.target_grade
    assert_equal 1, to_update.target_grade
  end

  def test_change_project_compile_portfolio
    project = Project.first
    to_update = project
    puts project.to_json

    # Perform update, change project compile portfolio
    put_json with_auth_token("/api/projects/#{project.id}"), { compile_portfolio: true }
    
    # Check if the call success
    assert 200, last_response.status

    # Update to_update data
    to_update.reload

    # Check if the update compile portfolio match as to_update.compile_portfolio
    assert_equal true, to_update.compile_portfolio
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
