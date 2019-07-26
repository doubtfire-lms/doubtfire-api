require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_status_comments
    project = Project.first
    user = project.student
    unit = project.unit
    main_tutor = project.main_tutor

    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
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
      trigger: 'ready_to_mark',
    }

    # Submit
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/submission", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["status"] == 'time_exceeded', "Error: Submission after deadline... should be time exceeded"

    task = Task.find(response['id'])

    assert_equal 2, task.comments.count

    rtm_comment = task.comments.all[-2]
    te_comment = task.comments.all[-1]

    assert rtm_comment.read_by?(user), 'Error: RTM status comment should be ready by the student'
    refute rtm_comment.read_by?(main_tutor), 'Error: TE status comment should not be ready by the tutor'

    assert te_comment.read_by?(main_tutor), 'Error: TE status comment should be ready by the tutor'
    refute te_comment.read_by?(user), 'Error: TE status comment should not be ready by the student'

    td.destroy!
  end

end
