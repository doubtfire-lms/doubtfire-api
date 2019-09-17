require 'test_helper'

class TaskStatusTest < ActiveSupport::TestCase
  test 'ensure status matches id' do
    TaskStatus.all.each do |ts|
      assert_equal TaskStatus.id_to_key(ts.id), ts.status_key 
    end
  end 
	unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'Task past due - for revert',
        description: 'Task past due',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskPastDueForRevert',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save! 
	
	# Get the first student - who now has this task
    project = unit.active_projects.first
	
	data_to_post = {
      trigger: 'ready_to_mark'
    }
	
    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    # Get the task... check it is now time exceeded
    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.time_exceeded, task.task_status
end
end
