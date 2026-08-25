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

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        abbreviation: 'test_status_comments',
        name: 'test_status_comments',
        description: 'test_status_comments',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.day,
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    tutor = project.tutor_for(td)

    data_to_post = {
      trigger: 'ready_for_feedback',
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Submit
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["status"] == 'time_exceeded', "Error: Submission after deadline... should be time exceeded"

    task = Task.find(response['id'])

    assert_equal 2, task.comments.count

    rff_comment = task.comments.where(task_status_id: TaskStatus.ready_for_feedback.id).first
    te_comment = task.comments.where(task_status_id: TaskStatus.time_exceeded.id).first

    # Status comments are attention_audience :none, so they never sit unread in the
    # comment inbox for anyone - they raise a notification instead.
    assert rff_comment.attention_none?, 'Error: RFF status comment should not require attention'
    assert te_comment.attention_none?, 'Error: TE status comment should not require attention'

    assert rff_comment.read_by?(user), 'Error: RFF status comment should be read by the student'
    assert rff_comment.read_by?(tutor), 'Error: RFF status comment should be read by the tutor'

    assert te_comment.read_by?(tutor), 'Error: TE status comment should be read by the tutor'
    assert te_comment.read_by?(user), 'Error: TE status comment should be read by the student'

    # The student has not opened the task, so the staff status change is unseen and notified.
    assert_not te_comment.seen_by?(user), 'Error: TE status comment should not be seen by the student'
    assert Notification.exists?(source: te_comment, recipient: user, kind: 'task_status_changed'),
           'Error: TE status comment should notify the student'

    td.destroy!
  end

end
