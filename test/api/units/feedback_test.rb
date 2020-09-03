require 'test_helper'

class FeedbackTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_awaiting_feedback
    unit = FactoryBot.create(:unit, perform_submissions: true, unenrolled_student_count: 0, part_enrolled_student_count: 0)

    unit.teaching_staff.each do |user|
      expected_response = unit.tasks_awaiting_feedback(user)
      
      # Add auth_token and username to header
      add_auth_header_for({}, user)

      get "/api/units/#{unit.id}/feedback"

      assert_equal 200, last_response.status

      # check each is the same
      last_response_body.zip(expected_response).each do |response, expected|
        assert_json_matches_model expected, response, ['id']
      end
    end
  end

  def test_tasks_for_task_inbox
    unit = FactoryBot.create(:unit, perform_submissions: true, unenrolled_student_count: 0, part_enrolled_student_count: 0, tutorials: 2, staff_count: 2)

    expected_count = unit.tasks.where(task_status: [ TaskStatus.ready_to_mark, TaskStatus.need_help ]).count

    unit.teaching_staff.each do |user|
      expected_response = unit.tasks_for_task_inbox(user)

      # Add auth_token and username to header
      add_auth_header_for({}, user)

      get "/api/units/#{unit.id}/tasks/inbox"

      assert_equal 200, last_response.status

      assert_equal expected_count, last_response_body.count, last_response_body

      # check each is the same
      last_response_body.zip(expected_response).each do |response, expected|
        assert_json_matches_model expected, response, ['id']
      end
    end
  end
end
