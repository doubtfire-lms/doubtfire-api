require 'test_helper'

class ProjectsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_projects_get_by_id
    # Test getting the first unit with id of 1
    get with_auth_token '/api/projects/1'

    actual_project = last_response_body
    expected_project = Project.find(1)

    # Check to see if the first project match
    assert_equal actual_project['enrolled'], expected_project.enrolled
    assert_equal actual_project['tutorial_id'], expected_project.tutorial_id
    assert_equal actual_project['unit_id'], expected_project.start_date.unit_id
    assert_equal actual_project['user_id'], expected_project.start_date.user_id

  end

  # POST /api/projects{id}/projects.json
  def test_project_post
    number_of_projects = Project.all.length

    data_to_post = {
      unit_id: '1',
      student_num: 'test4@doubtfire.com', #use email insted of number
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/projects', data_to_post

    # Check there is a new project
    assert_equal Project.all.length, number_of_projects + 1
  end

  def test_project_post_invalid_token()
    number_of_projects = Project.all.length

    data_to_post = {
      unit_id: '1',
      student_num: 'test4@doubtfire.com',
      auth_token: 'abvedg'
    }

    post_json '/api/projects', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal number_of_projects, Project.all.length
    assert_equal 419, last_response.status
  end

  def test_project_post_empty_token()
     number_of_projects = Project.all.length

    data_to_post = {
      unit_id: '1',
      student_num: 'test4@doubtfire.com',
      auth_token: ''
    }

    post_json '/api/projects', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal number_of_projects, Project.all.length
    assert_equal 419, last_response.status
  end

  # test project with valid id
  def test_project_put
    number_of_projects = Project.all.length

    project_old = Project.find(1)

    data_to_post = {
      old_grade: project_old.old_grade,
      grade_rationale: 'Grade Rationale',
      grade: project_old.old_grade,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/projects/1', data_to_post

    project_new = last_response_body

    # Check there is a new project
    assert_equal project_new['grade'], project_old.old_grade
    assert_equal Project.all.length, number_of_projects
  end

  # test project with invalid old_grade
  def test_project_put
    number_of_projects = Project.all.length

    project_old = Project.find(1)

    data_to_post = {
      old_grade: '',
      grade_rationale: 'Grade Rationale',
      grade: project_old.old_grade,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/projects/1', data_to_post
    assert_equal 400, last_response.status
  end

end
