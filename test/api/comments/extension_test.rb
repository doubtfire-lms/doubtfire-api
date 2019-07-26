require 'test_helper'

class ExtensionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_extension_application
    project = Project.first
    user = project.student
    unit = project.unit

    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!
    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Request a 2 day extension
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    # Request a 2 week extension on the day
    td.due_date = Time.zone.now + 2.weeks
    td.save!
    data_to_post["weeks_requested"] = '2'

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 2, "Error: Weeks requested weeks should be 2, found #{response["weeks_requested"]}."

    # Ask for too long an extension
    data_to_post["weeks_requested"] = '5'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Allowed too long of a request to be applied."

    # Ask for 0 week extension
    data_to_post["weeks_requested"] = '0'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Should not allow 0 week extension requests"

    td.destroy!
  end

end
