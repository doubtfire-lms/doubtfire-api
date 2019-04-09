require 'test_helper'

class TasksTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # WIP
  def test_task_get
    # The GET we are testing
    get with_auth_token '/api/tasks?unit_id=1'
    expected_data = Unit.first.student_tasks.where('task_status_id > ?', 1)

    last_response_body.each_with_index do |r, i|
      #   assert_json_matches_model r, expected_data[i].as_json, ['id', 'tutorial_id', 'task_definition_id', 'status']
    end
  end

  def test_time_exceeded_grade
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'Task past due',  
        description: 'Task past due',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        abbreviation: 'TaskPastDue',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: true,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    project = unit.active_projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert_equal -1, task.grade
    assert_equal TaskStatus.time_exceeded, task.task_status
    
    td.destroy
  end

end
