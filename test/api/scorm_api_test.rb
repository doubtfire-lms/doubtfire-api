require 'test_helper'

class ScormApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def scorm_path(task_def, user, file, token_type = :scorm)
    "/api/scorm/#{task_def.id}/#{user.username.gsub('.', '%2e')}/#{auth_token(user, token_type)}/#{file}"
  end

  def test_serve_scorm_content
    unit = FactoryBot.create(:unit)
    user = unit.projects.first.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task scorm',
        description: 'Task with scorm test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskScorm',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_allow_review: true,
        scorm_bypass_test: false,
        scorm_time_delay_enabled: false,
        scorm_attempt_limit: 0
      }
    )
    td.save!

    # When the task def does not have SCORM data
    get scorm_path(td, user, 'index.html')
    assert_equal 404, last_response.status

    td.add_scorm_data(test_file_path('numbas.zip'), copy: true)
    td.save!

    # When the file is missing
    get scorm_path(td, user, 'index1.html')
    assert_equal 404, last_response.status

    # When the file is present - html
    get scorm_path(td, user, 'index.html')
    assert_equal 200, last_response.status
    assert_equal 'text/html', last_response.content_type

    # Cannot access with the wrong token type
    get scorm_path(td, user, 'index.html', :general)
    assert_equal 419, last_response.status

    get scorm_path(td, user, 'index.html', :login)
    assert_equal 419, last_response.status

    # When the file is present - css
    get scorm_path(td, user, 'styles.css')
    assert_equal 200, last_response.status
    assert_equal 'text/css', last_response.content_type

    # When the file is present - js
    get scorm_path(td, user, 'scripts.js')
    assert_equal 200, last_response.status
    assert_equal 'text/javascript', last_response.content_type

    tutor = FactoryBot.create(:user, :tutor, username: :test_tutor)

    # When the user is unauthorised
    get scorm_path(td, tutor, 'index.html')
    assert_equal 403, last_response.status

    tutor.destroy!
    td.destroy!
    unit.destroy!
  end
end
