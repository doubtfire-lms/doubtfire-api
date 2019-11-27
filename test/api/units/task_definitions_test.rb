require 'test_helper'

class TaskDefinitionsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_post_invalid_file_tasksheet
    test_unit = Unit.first
    test_task_definition_id = test_unit.task_definitions.first.id

    data_to_post = {
      file: 'rubbish_path',
      auth_token: auth_token
    }
    post_json with_auth_token("/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet"), data_to_post

    assert last_response_body.key?('error')
  end

  def test_post_tasksheet
    test_unit = Unit.first
    test_task_definition = TaskDefinition.first

    data_to_post = {
      file: Rack::Test::UploadedFile.new('test_files/submissions/00_question.pdf', 'application/pdf')
    }

    post "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition.id}/task_sheet", with_auth_token(data_to_post)

    assert_equal 201, last_response.status
    assert test_task_definition.task_sheet

    assert_equal File.size('test_files/submissions/00_question.pdf'), File.size(TaskDefinition.first.task_sheet)
  end

  def test_post_task_resources
    test_unit_id = Unit.first.id
    test_task_definition_id = TaskDefinition.first.id

    data_to_post = {
      file: Rack::Test::UploadedFile.new('test_files/2015-08-06-COS10001-acain.zip', 'application/zip')
    }
    post "/api/units/#{test_unit_id}/task_definitions/#{test_task_definition_id}/task_resources", with_auth_token(data_to_post)

    puts last_response_body if last_response.status == 403

    assert_equal 201, last_response.status
  end

  def test_submission_creates_folders
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'test_submission_creates_folders',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'test_submission_creates_folders',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'document' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/00_question.pdf', 'application/pdf', data_to_post)

    project = unit.active_projects.first

    path = FileHelper.student_work_dir(:new, nil, false)
    FileUtils.rm_rf path
    
    assert_not File.directory? path

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    assert File.directory? path

    task = project.task_for_task_definition(td)

    assert File.directory? FileHelper.student_work_dir(:new, task, false)
    assert File.exists? File.join(FileHelper.student_work_dir(:new, task, false), '000-document.pdf')

    task.destroy

    assert_not File.directory? FileHelper.student_work_dir(:new, task, false)

    td.destroy
  end

  def test_change_to_group_after_submissions
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task to switch from ind to group after submission',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskSwitchIndGrp',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'document' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/00_question.pdf', 'application/pdf', data_to_post)

    project = unit.active_projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exists? path
    
    # Change it to a group task

    group_set = GroupSet.create!({name: 'test group set', unit: unit})
    group_set.save!

    td.group_set = group_set
    assert !td.save

    task.reload()
    task.task_definition = td
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exists? path

    td.destroy
    assert_not File.exists? path
  end

  def test_task_related_to_task_def
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    task_def = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task = project.task_for_task_definition(task_def)

    # Reload the unit
    unit.reload

    assert_equal 1, unit.student_tasks.count
    assert_equal task, unit.student_tasks.first

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_its_stream_is_null
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = nil
    task_def_first = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_def_second = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_equal task_first, unit.student_tasks.first
    assert_equal task_second, unit.student_tasks.second

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the second task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']

    tutorial = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_enrolment = project.enrol_in(tutorial)

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial.id, last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the second task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial.id, last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_project_is_in_match_all
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    task_def_first = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_def_second = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_not_nil task_def_first.tutorial_stream
    assert_not_nil task_def_second.tutorial_stream
    assert_equal task_first, unit.student_tasks.first
    assert_equal task_second, unit.student_tasks.second

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the second task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']

    tutorial_stream = nil
    tutorial = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_enrolment = project.enrol_in(tutorial)

    # Make sure project is in match all
    assert_nil tutorial.tutorial_stream

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial.id, last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the second task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial.id, last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_multiple_tasks_but_project_is_not_enrolled
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryGirl.create(:tutorial_stream, unit: unit)
    task_def_first = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)

    tutorial_stream_second = FactoryGirl.create(:tutorial_stream, unit: unit)
    task_def_second = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_equal task_first, unit.student_tasks.first

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_multiple_tasks_but_project_is_enrolled_for_one
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus)
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    task_def_first = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)

    tutorial_stream_second = FactoryGirl.create(:tutorial_stream, unit: unit)
    task_def_second = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_equal task_first, unit.student_tasks.first
    assert_equal task_second, unit.student_tasks.second

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial_first.id, last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_project_is_enrolled
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_stream_second = FactoryGirl.create(:tutorial_stream, unit: unit)

    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_second, campus: campus)

    assert_not_nil tutorial_first.tutorial_stream
    assert_not_nil tutorial_second.tutorial_stream

    assert_equal tutorial_stream_first, tutorial_first.tutorial_stream
    assert_equal tutorial_stream_second, tutorial_second.tutorial_stream

    # Enrol project in tutorial first and second
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    tutorial_enrolment_second = project.enrol_in(tutorial_second)

    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal project, tutorial_enrolment_second.project

    task_def_first = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_def_second = FactoryGirl.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)

    task_first = project.task_for_task_definition(task_def_first)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_equal task_first, unit.student_tasks.first
    assert_equal task_second, unit.student_tasks.second

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial_first.id, last_response_body.first['tutorial_id']
    assert_equal task_first.id, last_response_body.first['id']

    # Get the tasks for the second task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal tutorial_second.id, last_response_body.first['tutorial_id']
    assert_equal task_second.id, last_response_body.first['id']
  end
 end
