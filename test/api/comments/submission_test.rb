require 'test_helper'

class SubmissionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_student_request_and_staff_approval
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student
    td = unit.task_definitions.first
    task = project.task_for_task_definition(td)
    endpoint = "/api/projects/#{project.id}/task_def_id/#{td.id}"

    add_auth_header_for(user: user)
    data_to_post = {
      comment: 'I have completed an attempt and would like feedback.'
    }

    # Request early submission access as the student.
    post_json "#{endpoint}/request_submission_access", data_to_post
    assert_equal 201, last_response.status
    response = last_response_body
    assert_equal 'submission', response['type']
    request = SubmissionComment.find(response['id'])
    assert_equal task, request.task
    assert_equal task.tutor, request.recipient
    assert_not request.assessed?

    add_auth_header_for(user: user)
    put_json "#{endpoint}/assess_submission_access/#{request.id}", { granted: true }
    assert_equal 403, last_response.status
    assert_not request.reload.assessed?

    add_auth_header_for(user: unit.main_convenor_user)
    put_json "#{endpoint}/assess_submission_access/#{request.id}", { granted: true }
    assert_equal 200, last_response.status
    assert_equal true, last_response_body['submission_granted']
    assert request.reload.approved?

    add_auth_header_for(user: unit.main_convenor_user)
    put_json "#{endpoint}/assess_submission_access/#{request.id}", { granted: false }
    assert_equal 403, last_response.status
    assert request.reload.approved?

    unit.destroy!
  end

  def test_blank_reason_is_rejected
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student
    td = unit.task_definitions.first
    endpoint = "/api/projects/#{project.id}/task_def_id/#{td.id}"

    add_auth_header_for(user: user)
    assert_no_difference 'SubmissionComment.count' do
      post_json "#{endpoint}/request_submission_access", { comment: '   ' }
      assert_equal 400, last_response.status
    end

    unit.destroy!
  end

  # def test_staff_can_deny_but_cannot_assess_an_ordinary_comment
  #   unit = FactoryBot.create(:unit)
  #   project = unit.projects.first
  #   user = project.student
  #   td = unit.task_definitions.first
  #   task = project.task_for_task_definition(td)
  #   endpoint = "/api/projects/#{project.id}/task_def_id/#{td.id}"

  #   # Create a submission access request for the student.
  #   request = task.apply_for_submission_access(user, 'Please review my early submission request.')
  #   add_auth_header_for(user: unit.main_convenor_user)
  #   put_json "#{endpoint}/assess_submission_access/#{request.id}", { granted: false }
  #   assert_equal 200, last_response.status
  #   assert request.reload.assessed?
  #   assert_not request.approved?

  #   # An ordinary comment must not be assessed as a submission access request.
  #   comment = task.add_text_comment(user, 'An ordinary task comment')
  #   add_auth_header_for(user: unit.main_convenor_user)
  #   put_json "#{endpoint}/assess_submission_access/#{comment.id}", { granted: true }
  #   assert_equal 404, last_response.status

  #   unit.destroy!
  # end
end
