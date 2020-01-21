require 'test_helper'

class TaskStatusTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper

  def app
    Rails.application
  end

  def test_ensure_status_matches_id
    TaskStatus.all.each do |ts|
      assert_equal TaskStatus.id_to_key(ts.id), ts.status_key
    end
  end

  def test_status_chanaged_with_extenssion
    unit = FactoryBot.create :unit
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
        max_quality_pts: 0,
        tutorial_stream_id: nil
      })
    td.save!

    #create a time exceeded task
    tc = Task.create!(
      task_definition_id: td.id,
      task_status_id: 12
    )

    # Get the first student - who now has this task
    project = unit.active_projects.first

    data_to_post = {
      trigger: 'ready_to_mark'
    }
    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    # Get the exceeded exceeded task and check it is now time exceeded
    #task = project.task_for_task_definition(td)
    assert_equal TaskStatus.time_exceeded, tc.task_status
  end

  def test_status_for_name
      assert_equal TaskStatus.status_for_name('complete').name,TaskStatus.complete.name
      assert_equal TaskStatus.status_for_name('fix_and_resubmit').name,TaskStatus.fix_and_resubmit.name
      assert_equal TaskStatus.status_for_name('fix and resubmit').name,TaskStatus.fix_and_resubmit.name
      assert_equal TaskStatus.status_for_name('fix').name,TaskStatus.fix_and_resubmit.name
      assert_raise NoMethodError do
        assert_equal TaskStatus.status_for_name('f').name,TaskStatus.fix.name
      end

      assert_equal TaskStatus.status_for_name('do_not_resubmit').name,TaskStatus.do_not_resubmit.name
      assert_equal TaskStatus.status_for_name('do not resubmit').name,TaskStatus.do_not_resubmit.name
      assert_equal TaskStatus.status_for_name('redo').name,TaskStatus.redo.name

      assert_equal TaskStatus.status_for_name('need_help').name,TaskStatus.need_help.name
      assert_equal TaskStatus.status_for_name('need help').name,TaskStatus.need_help.name
      assert_equal TaskStatus.status_for_name('working_on_it').name,TaskStatus.working_on_it.name
      assert_equal TaskStatus.status_for_name('working on it').name,TaskStatus.working_on_it.name
      assert_equal TaskStatus.status_for_name('discuss').name,TaskStatus.discuss.name
      assert_equal TaskStatus.status_for_name('d').name,TaskStatus.discuss.name

      assert_equal TaskStatus.status_for_name('demonstrate').name,TaskStatus.demonstrate.name
      assert_equal TaskStatus.status_for_name('demo').name,TaskStatus.demonstrate.name
      assert_equal TaskStatus.status_for_name('ready to mark').name,TaskStatus.ready_to_mark.name
      assert_equal TaskStatus.status_for_name('ready_to_mark').name,TaskStatus.ready_to_mark.name
      assert_equal TaskStatus.status_for_name('rtm').name,TaskStatus.ready_to_mark.name

      assert_equal TaskStatus.status_for_name('fail').name,TaskStatus.fail.name
      assert_equal TaskStatus.status_for_name('not_started').name,TaskStatus.not_started.name
      assert_equal TaskStatus.status_for_name('not started').name,TaskStatus.not_started.name
      assert_equal TaskStatus.status_for_name('ns').name,TaskStatus.not_started.name
      assert_equal TaskStatus.status_for_name('time exceeded').name,TaskStatus.time_exceeded.name
      assert_equal TaskStatus.status_for_name('time_exceeded').name,TaskStatus.time_exceeded.name
      assert_equal TaskStatus.status_for_name(''), nil
  end

  def test_staff_assigned_statuses
    assert_equal TaskStatus.staff_assigned_statuses.count,8 # number of staff tasks
  end


  def test_id_to_key_not_started
    assert_equal TaskStatus.id_to_key(13), :not_started
  end

end
