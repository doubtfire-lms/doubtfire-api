require 'test_helper'
require 'date'
require './lib/helpers/database_populator'

class ProjectsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_can_get_projects
    user = FactoryBot.create(:user, :student, enrol_in: 1)

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    get '/api/projects'
    assert_equal 200, last_response.status
  end

  def test_get_projects_with_streams_match
    unit = FactoryBot.create :unit, stream_count: 2, campus_count: 2, tutorials: 2, unenrolled_student_count: 0, part_enrolled_student_count: 0, inactive_student_count: 0
    project = unit.projects.first
    assert_equal 2, project.tutorial_enrolments.count

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    get '/api/projects'
    assert_equal 200, last_response.status
    assert_equal 1, last_response_body.count, last_response_body
  end

  def test_projects_returns_correct_number_of_projects
    user = FactoryBot.create(:user, :student, enrol_in: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    get '/api/projects'
    assert_equal 2, last_response_body.count
  end

  def test_projects_returns_correct_data
    user = FactoryBot.create(:user, :student, enrol_in: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    keys = %w(id unit campus_id user_id target_grade portfolio_available)
    key_test = %w(campus_id target_grade)

    get '/api/projects'
    assert_equal 2, last_response_body.count, last_response_body
    last_response_body.each do |data|
      project = user.projects.find(data['id'])
      assert project.present?, data.inspect

      assert_json_limit_keys_to_exactly keys, data

      assert_json_matches_model(project, data, %w(campus_id target_grade campus_id))
      assert_json_matches_model(project.unit, data['unit'], %w(id code name active))

      assert_json_matches_model project, data, key_test
    end
  end

  def test_get_project_response_is_correct
    user = FactoryBot.create(:user, :student, enrol_in: 1)
    project = user.projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    keys = %w(id unit unit_id user_id campus_id target_grade submitted_grade portfolio_files compile_portfolio portfolio_available uses_draft_learning_summary tasks tutorial_enrolments groups task_outcome_alignments)
    key_test = keys - %w(unit user_id portfolio_available tasks tutorial_enrolments groups task_outcome_alignments)

    get "/api/projects/#{project.id}"
    assert_equal 200, last_response.status, last_response_body

    assert_json_limit_keys_to_exactly keys, last_response_body
    assert_json_matches_model project, last_response_body, key_test
  end

  def test_projects_works_with_inactive_units
    user = FactoryBot.create(:user, :student, enrol_in: 2)
    Unit.last.update(active: false)

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    get '/api/projects'
    assert_equal 1, last_response_body.count

    get '/api/projects?include_inactive=false'
    assert_equal 1, last_response_body.count

    get '/api/projects?include_inactive=true'

    assert_equal 2, last_response_body.count

    last_response_body.each do |data|
      project = user.projects.find(data['id'])
      assert project.present?, data.inspect

      assert_json_matches_model(project, data, %w(campus_id target_grade campus_id))
      assert_json_matches_model(project.unit, data['unit'], %w(code id name active))
    end
  end

  def test_submitted_grade_cant_change_after_submission
    user = FactoryBot.create(:user, :student, enrol_in: 1)
    project = user.projects.first

    data_to_put = {
      id: project.id,
      submitted_grade: 2
    }

    add_auth_header_for(user: user)

    put_json "/api/projects/#{project.id}", data_to_put
    project.reload

    assert_equal 200, last_response.status, last_response_body
    assert_equal user.projects.find(project.id).submitted_grade, 2

    keys = %w(campus_id target_grade submitted_grade compile_portfolio portfolio_available uses_draft_learning_summary)

    assert_json_limit_keys_to_exactly keys, last_response_body
    assert_json_matches_model project, last_response_body, keys

    DatabasePopulator.generate_portfolio(project)

    data_to_put['submitted_grade'] = 1

    put_json "/api/projects/#{project.id}", data_to_put

    assert_not_equal user.projects.find(project.id).submitted_grade, 1
    assert_equal 403, last_response.status
  end

  def test_download_portfolio
    project = FactoryBot.create(:project)
    unit = project.unit

    project.portfolio_production_date = Time.zone.now
    project.save

    `fallocate -l 10M #{project.portfolio_path}`

    assert File.exist?(project.portfolio_path)
    assert project.portfolio_exists?

    data_to_put = {
      as_attachment: true
    }

    add_auth_header_for(user: project.student)

    get "/api/submission/project/#{project.id}/portfolio", data_to_put
    assert_equal 200, last_response.status
    assert last_response.headers['Content-Disposition'].starts_with?('attachment; filename=')
    assert_equal 'Content-Disposition', last_response.headers['Access-Control-Expose-Headers']
    assert last_response.headers['Content-Type'] == 'application/pdf'
    assert 10_485_760, last_response.length

    `fallocate -l 11M #{project.portfolio_path}`
    get "/api/submission/project/#{project.id}/portfolio", data_to_put
    assert_equal 206, last_response.status
    assert 10_485_760, last_response.length

    data_to_put = {
      as_attachment: false
    }

    add_auth_header_for(user: project.student)
    header 'range', 'bytes=1000-1500'

    get "/api/submission/project/#{project.id}/portfolio", data_to_put
    assert 500, last_response.length
    assert_equal 206, last_response.status
    assert_nil last_response.headers['Content-Disposition']
    assert_equal 'Content-Range,Accept-Ranges', last_response.headers['Access-Control-Expose-Headers']
    assert last_response.headers['Content-Type'] == 'application/pdf'

    unit.destroy!
  ensure
    FileUtils.rm_f(project.portfolio_path)
  end
end
