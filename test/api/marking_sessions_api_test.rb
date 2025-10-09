require 'test_helper'

class MarkingSessionsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include ActiveSupport::Testing::TimeHelpers

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit)
    @tutor = FactoryBot.create(:user, :tutor)
    @convenor = FactoryBot.create(:user, :convenor)
    @student = FactoryBot.create(:user, :student)
    @project = FactoryBot.create(:project, unit: @unit, user: @student)
    @task = FactoryBot.create(:task, project: @project)
    @unit.employ_staff(@tutor, Role.tutor)
    @unit.employ_staff(@convenor, Role.convenor)
    @marking_session = FactoryBot.create(:marking_session,
                                         user: @tutor,
                                         unit: @unit,
                                         ip_address: '127.0.0.1',
                                         start_time: 1.hour.ago,
                                         end_time: Time.zone.now)
  end

  def test_marking_session_permissions
    unit = FactoryBot.create(:unit, student_count: 2, task_count: 2)

    project = unit.projects.first
    td = unit.task_definitions.first
    student = unit.projects.first.user
    tutor = FactoryBot.create(:user, :tutor)
    convenor = FactoryBot.create(:user, :convenor)

    unit.employ_staff(tutor, Role.tutor)
    unit.employ_staff(convenor, Role.convenor)

    tracked_users = [
      convenor, tutor
    ]

    untracked_users = [
      student
    ]

    tracked_users.each do |user|
      SessionActivity.delete_all
      MarkingSession.delete_all
      add_auth_header_for(user: user)
      get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
      assert_equal 200, last_response.status
      last_session = MarkingSession.last
      last_activity = SessionActivity.last

      assert_not last_session.nil?
      assert_not last_activity.nil?
      assert user, last_session.user
    end

    untracked_users.each do |user|
      SessionActivity.delete_all
      MarkingSession.delete_all
      add_auth_header_for(user: user)
      get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
      assert_equal 200, last_response.status
      last_session = MarkingSession.last
      last_activity = SessionActivity.last

      assert last_session.nil?
      assert last_activity.nil?
    end

    users_can_get = [
      convenor
    ]

    users_cant_get = [
      student, tutor
    ]

    users_can_get.each do |user|
      add_auth_header_for(user: user)
      get "/api/units/#{unit.id}/marking_sessions"
      assert_equal 200, last_response.status
    end

    users_cant_get.each do |user|
      add_auth_header_for(user: user)
      get "/api/units/#{unit.id}/marking_sessions"
      assert_equal 403, last_response.status
    end
  end

  def test_marking_sessions
    unit = FactoryBot.create(:unit, student_count: 2, task_count: 2)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    project = unit.projects.first
    td = unit.task_definitions.first

    # Delete all sessions and activities
    SessionActivity.delete_all
    MarkingSession.delete_all

    # Load a submission from the inbox as a tutor

    add_auth_header_for(user: tutor)

    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
    assert_equal 200, last_response.status

    # Ensure new session has started and activity was created
    last_session = MarkingSession.last
    last_activity = SessionActivity.last

    assert_not last_session.nil?
    assert_not last_activity.nil?

    # > Force the session to be 10 minutes in the past
    travel 10.minutes
    travel 5.seconds # Ensure we're past the 10 minute mark

    # Create a comment as the tutor, ensure activity was created
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
    assert_equal 200, last_response.status

    last_session = MarkingSession.last
    last_activity = SessionActivity.last

    assert_equal 10, last_session.duration_minutes

    # Ensure activity points to the same session
    assert_equal last_session, last_activity.marking_session

    # Ensure only one session exists still, ensure the duration has been updated to 10 minutes
    assert_equal 1, MarkingSession.count

    # Force the session to now be 30 minutes in the past
    travel 30.minutes # Go past the 15 minute threshold

    # Assess a task, ensure activity was created
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
    assert_equal 200, last_response.status
    assert_equal 2, MarkingSession.count

    new_session = MarkingSession.last
    last_activity = SessionActivity.last

    # Ensure a new session was created
    assert_not_equal new_session, last_session

    # TODO: lazy
    assert_equal 3, SessionActivity.count

    assert_equal 10, last_session.duration_minutes
    assert_equal 0, new_session.duration_minutes
  end

  def test_assesment_activities
    unit = FactoryBot.create(:unit, student_count: 2, task_count: 2)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    project = unit.projects.first
    td = unit.task_definitions.first

    SessionActivity.delete_all
    MarkingSession.delete_all

    add_auth_header_for(user: tutor)

    # Test add comment
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", { comment: "Test" }
    assert_equal 201, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "add-comment", last_activity.action

    # Test get comments
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/comments"
    assert_equal 200, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "get-comments", last_activity.action

    # Test delete comment
    delete "/api/projects/#{project.id}/task_def_id/#{td.id}/comments/#{TaskComment.last.id}"
    assert_equal 204, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "delete-comment", last_activity.action

    # Test asessment
    put "/api/projects/#{project.id}/task_def_id/#{td.id}", { trigger: 'complete' }
    assert_equal 200, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "assessing", last_activity.action

    # Test get sunmission details
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"
    assert_equal 200, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "get-submission-details", last_activity.action

    # Test get sunmission files
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_files"
    assert_equal 200, last_response.status
    last_activity = SessionActivity.last
    assert_equal project.id, last_activity.project.id
    assert_equal "get-submission-files", last_activity.action
  end

  # def test_get_specific_marking_session
  #   add_auth_header_for(user: @tutor)
  #   get "/api/marking_sessions/#{@marking_session.id}"
  #   assert_equal 200, last_response.status
  #   response_data = last_response_body
  #   assert_equal @marking_session.id, response_data['id']
  #   assert_equal @marking_session.user_id, response_data['user_id']
  #   assert_equal @marking_session.unit_id, response_data['unit_id']
  # end

  # def test_get_marking_sessions_by_tutor_id
  #   add_auth_header_for(user: @convenor)
  #   get "/api/marking_sessions/tutor/#{@tutor.id}"
  #   assert_equal 200, last_response.status
  #   response_data = last_response_body
  #   assert_equal 1, response_data.length
  #   assert_equal @marking_session.id, response_data[0]['id']
  # end

  # def test_get_tutor_analytics
  #   add_auth_header_for(user: @convenor)
  #   get "/api/marking_analytics/unit/#{@unit.id}/tutor/#{@tutor.id}"
  #   assert_equal 200, last_response.status, last_response_body
  #   response_data = last_response_body
  #   assert_equal 1, response_data['total_sessions']
  #   assert_equal 60, response_data['total_duration_minutes']
  # end

  # def test_unauthorized_access_to_other_tutor_session
  #   other_tutor = FactoryBot.create(:user, :tutor)
  #   add_auth_header_for(user: other_tutor)
  #   get "/api/marking_sessions/#{@marking_session.id}"
  #   assert_equal 403, last_response.status
  # end
end
