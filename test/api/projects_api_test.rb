require 'test_helper'
require 'date'
require './lib/helpers/database_populator'

class ProjectsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActiveSupport::Testing::TimeHelpers
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

    keys = %w[id unit campus_id user_id target_grade portfolio_available spec_con_days escalation_attempts_remaining]
    key_test = %w[campus_id target_grade spec_con_days]

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

    keys = %w[id unit unit_id user_id campus_id target_grade submitted_grade portfolio_files compile_portfolio portfolio_available uses_draft_learning_summary tasks tutorial_enrolments groups spec_con_days escalation_attempts_remaining]
    key_test = keys - %w[unit user_id portfolio_available tasks tutorial_enrolments groups]

    get "/api/projects/#{project.id}"
    assert_equal 200, last_response.status, last_response_body

    assert_json_limit_keys_to_exactly keys, last_response_body
    assert_json_matches_model project, last_response_body, key_test
  end

  def test_get_project_records_when_student_viewed_it
    user = FactoryBot.create(:user, :student, enrol_in: 1)
    project = user.projects.first
    viewed_at = Time.zone.parse('2026-07-21 12:00:00 UTC')
    add_auth_header_for(user: user)

    travel_to(viewed_at) { get "/api/projects/#{project.id}" }

    assert_equal 200, last_response.status
    assert_equal viewed_at, project.reload.last_viewed_at
  end

  def test_get_project_does_not_record_staff_view_as_student_view
    project = FactoryBot.create(:project)
    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    get "/api/projects/#{project.id}"

    assert_equal 200, last_response.status
    assert_nil project.reload.last_viewed_at
  end

  def test_get_project_can_record_attendance_during_enrolled_tutorial
    project, tutor, tutorial = attendance_test_data
    attended_at = Time.zone.parse('2026-07-20 10:30:00 UTC')
    tutorial.update!(meeting_day: 'Monday', meeting_time: '10:00')
    add_auth_header_for(user: tutor)

    assert_difference 'Engagement.count', 1 do
      travel_to(attended_at) { get "/api/projects/#{project.id}?record_attendance=true" }
    end

    assert_equal 200, last_response.status
    attendance = project.engagements.last
    assert_equal tutor, attendance.user
    assert_equal 'Attendance', attendance.engagement_type
    assert_equal 'Attended tutorial and QR scanned.', attendance.note
    assert_equal attended_at, attendance.occurred_at
  end

  def test_get_project_does_not_record_attendance_outside_enrolled_tutorial
    project, tutor, tutorial = attendance_test_data
    tutorial.update!(meeting_day: 'Monday', meeting_time: '10:00')
    add_auth_header_for(user: tutor)

    assert_no_difference 'Engagement.count' do
      travel_to(Time.zone.parse('2026-07-20 12:00:00 UTC')) do
        get "/api/projects/#{project.id}?record_attendance=true"
      end
    end

    assert_equal 200, last_response.status
  end

  def test_get_project_debounces_attendance_for_fifteen_minutes
    project, tutor, tutorial = attendance_test_data
    tutorial.update!(meeting_day: 'Monday', meeting_time: '10:00')
    add_auth_header_for(user: tutor)

    assert_difference 'Engagement.count', 1 do
      travel_to(Time.zone.parse('2026-07-20 10:30:00 UTC')) do
        get "/api/projects/#{project.id}?record_attendance=true"
      end
    end

    assert_no_difference 'Engagement.count' do
      travel_to(Time.zone.parse('2026-07-20 10:44:00 UTC')) do
        get "/api/projects/#{project.id}?record_attendance=true"
      end
    end

    assert_difference 'Engagement.count', 1 do
      travel_to(Time.zone.parse('2026-07-20 10:46:00 UTC')) do
        get "/api/projects/#{project.id}?record_attendance=true"
      end
    end
  end

  def test_get_project_rejects_attendance_trigger_without_unit_teaching_access
    project, = attendance_test_data
    add_auth_header_for(user: project.student)

    assert_no_difference 'Engagement.count' do
      get "/api/projects/#{project.id}?record_attendance=true"
    end

    assert_equal 403, last_response.status

    add_auth_header_for(user: FactoryBot.create(:user, :admin))
    assert_no_difference 'Engagement.count' do
      get "/api/projects/#{project.id}?record_attendance=true"
    end

    assert_equal 403, last_response.status
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

  private

  def attendance_test_data
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    tutorial = unit.tutorials.first
    tutorial.campus.update!(timezone: 'UTC')
    student = FactoryBot.create(:user, :student)
    project = unit.enrol_student(student, tutorial.campus)
    project.enrol_in(tutorial)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    [project, tutor, tutorial]
  end
end
