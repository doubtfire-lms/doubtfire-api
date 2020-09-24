require 'test_helper'

class TaskDefinitionsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def all_task_def_keys 
    [ 
      'name',
      'description',
      'target_grade',
      'group_set_id',
      'start_date',
      'target_date',
      'due_date',
      'abbreviation',
      'restrict_status_updates',
      'plagiarism_warn_pct',
      'is_graded',
      'max_quality_pts'
    ]
  end

  def test_task_definition_cud
    unit = FactoryBot.create(:unit, task_count: 0, group_sets: 1, stream_count: 1)

    assert_equal 0, unit.task_definitions.count

    data_to_post = {
      task_def: {
        tutorial_stream_abbr:     unit.tutorial_streams.first.abbreviation,
        name:                     'New Task Def',
        description:              'First task def',
        weighting:                4,
        target_grade:             1,
        group_set_id:             unit.group_sets.first.id,
        start_date:               unit.start_date,
        target_date:              unit.start_date + 7.days,
        due_date:                 unit.start_date + 21.days,
        abbreviation:             'P1.1',
        restrict_status_updates:  false,
        upload_requirements:      '[ { "key": "file0", "name": "Shape Class", "type": "document" } ]',
        plagiarism_checks:        '[]',
        plagiarism_warn_pct:      80,
        is_graded:                false,
        max_quality_pts:          0
      }
    }

    post_json with_auth_token("/api/units/#{unit.id}/task_definitions", unit.main_convenor_user), data_to_post
    assert_equal 201, last_response.status, last_response.inspect
    assert_equal 1, unit.task_definitions.count

    assert_json_matches_model unit.task_definitions.first, last_response_body, all_task_def_keys
    assert_equal unit.tutorial_streams.first.id, unit.task_definitions.first.tutorial_stream_id
    assert_equal 4, unit.task_definitions.first.weighting


    data_to_put = {
      task_def: {
        tutorial_stream_abbr:     unit.tutorial_streams.last.abbreviation,
        name:                     'New Task Def 1',
        description:              'First task def 1',
        weighting:                2,
        target_grade:             2,
        group_set_id:             nil,
        start_date:               unit.start_date + 2.days,
        target_date:              unit.start_date + 9.days,
        due_date:                 unit.start_date + 23.days,
        abbreviation:             'P1.2',
        restrict_status_updates:  true, 
        upload_requirements:      '[ { "key": "file0", "name": "Other Class", "type": "document" } ]',
        plagiarism_checks:        '[]',
        plagiarism_warn_pct:      80,
        is_graded:                false,
        max_quality_pts:          0
      }
    }

    put_json "/api/units/#{unit.id}/task_definitions/#{unit.task_definitions.first.id}", with_auth_token(data_to_put, unit.main_convenor_user)
    assert_equal 200, last_response.status, last_response.inspect

    unit.reload

    assert_json_matches_model unit.task_definitions.first, last_response_body, all_task_def_keys
    assert_equal unit.tutorial_streams.last.id, unit.task_definitions.first.tutorial_stream_id
    assert_equal 2, unit.task_definitions.first.weighting
  end

  def test_post_invalid_file_tasksheet
    test_unit = FactoryBot.create(:unit, task_count: 1)
    test_task_definition_id = test_unit.task_definitions.first.id

    data_to_post = {
      file: 'rubbish_path'
    }
    post_json with_auth_token("/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet", test_unit.main_convenor_user), data_to_post

    assert last_response_body.key?('error')
  end

  def test_post_tasksheet
    test_unit = Unit.first
    test_task_definition = TaskDefinition.first

    data_to_post = {
      file: upload_file('test_files/submissions/00_question.pdf', 'application/pdf')
    }

    post "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition.id}/task_sheet", with_auth_token(data_to_post)

    assert_equal 201, last_response.status
    assert test_task_definition.task_sheet

    assert_equal File.size(data_to_post[:file]), File.size(TaskDefinition.first.task_sheet)
  end

  def test_post_task_resources
    test_unit_id = Unit.first.id
    test_task_definition_id = TaskDefinition.first.id

    data_to_post = {
      file: upload_file('test_files/2015-08-06-COS10001-acain.zip', 'application/zip')
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
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    task_def = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
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
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = nil
    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
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

    tutorial = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
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
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream, target_grade: project.target_grade)
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
    tutorial = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
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
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)

    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)
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
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus)
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_first = project.task_for_task_definition(task_def_first)

    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)
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
    assert_nil last_response_body.first['tutorial_id'], last_response_body
    assert_equal task_second.id, last_response_body.first['id']
  end

  def test_task_related_to_task_def_when_project_is_enrolled
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)

    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_second, campus: campus)

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

    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)

    task_first = project.task_for_task_definition(task_def_first)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count
    assert_equal task_first, unit.student_tasks.first
    assert_equal task_second, unit.student_tasks.second

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 1, last_response_body.count, last_response_body
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

  def test_task_related_to_task_def_when_multiple_projects_tasks_and_tutorials
    unit = FactoryBot.create(:unit, with_students: false)

    assert_empty unit.projects
    assert_equal 1, unit.tutorials.count
    assert_equal 2, unit.task_definitions.count
    assert_empty unit.tasks
    assert_empty unit.student_tasks
    assert_empty unit.tutorial_streams

    unit.tutorials.clear
    unit.task_definitions.clear

    # Reload the unit
    unit.reload

    assert_empty unit.tutorials
    assert_empty unit.task_definitions

    unit.employ_staff(User.first, Role.convenor)

    campus_first = FactoryBot.create(:campus)
    campus_second = FactoryBot.create(:campus)
    campus_third = FactoryBot.create(:campus)

    # Create students for both campuses
    project_first = FactoryBot.create(:project, unit: unit, campus: campus_first)
    project_second = FactoryBot.create(:project, unit: unit, campus: campus_second)
    project_third = FactoryBot.create(:project, unit: unit, campus: campus_third)

    assert_equal 3, unit.projects.count

    # Make sure no existing enrolments
    assert_empty project_first.tutorial_enrolments
    assert_empty project_second.tutorial_enrolments

    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)

    assert_equal 2, unit.tutorial_streams.count

    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project_first.target_grade)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project_first.target_grade)
    task_def_third = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project_second.target_grade)
    task_def_fourth = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project_second.target_grade)

    assert_equal 4, unit.task_definitions.count
    assert_equal 2, tutorial_stream_first.task_definitions.count
    assert_equal 2, tutorial_stream_second.task_definitions.count

    task_first = project_first.task_for_task_definition(task_def_first)
    task_second = project_first.task_for_task_definition(task_def_second)

    task_third = project_second.task_for_task_definition(task_def_first)
    task_fourth = project_second.task_for_task_definition(task_def_third)

    task_fifth = project_third.task_for_task_definition(task_def_first)
    task_sixth = project_third.task_for_task_definition(task_def_fourth)

    # Reload the unit
    unit.reload

    assert_equal 6, unit.tasks.count
    assert_equal 6, unit.student_tasks.count
    assert_equal 2, project_first.tasks.count
    assert_equal 2, project_second.tasks.count
    assert_equal 2, project_third.tasks.count

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 3, last_response_body.count
    assert_includes [project_first.id, project_second.id, project_third.id], last_response_body.first['project_id']
    assert_includes [project_first.id, project_second.id, project_third.id], last_response_body.second['project_id']
    assert_includes [project_first.id, project_second.id, project_third.id], last_response_body.third['project_id']

    assert_includes [task_first.id, task_third.id, task_fifth.id], last_response_body.first['id']
    assert_includes [task_first.id, task_third.id, task_fifth.id], last_response_body.second['id']
    assert_includes [task_first.id, task_third.id, task_fifth.id], last_response_body.third['id']

    assert_nil last_response_body.first['tutorial_id']
    assert_nil last_response_body.first['tutorial_stream_id']

    assert_nil last_response_body.second['tutorial_id']
    assert_nil last_response_body.second['tutorial_stream_id']

    assert_nil last_response_body.third['tutorial_id']
    assert_nil last_response_body.third['tutorial_stream_id']

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_second.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project_first.id, last_response_body.first['project_id']
    assert_nil last_response_body.first['tutorial_id']
    assert_nil last_response_body.first['tutorial_stream_id']
    assert_equal task_second.id, last_response_body.first['id']

    # Create tutorials
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus_first)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_second, campus: campus_second)
    tutorial_third = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: nil, campus: campus_third)

    # Enrol projects
    tutorial_enrolment_first = project_first.enrol_in(tutorial_first)
    tutorial_enrolment_second = project_second.enrol_in(tutorial_second)
    tutorial_enrolment_third = project_third.enrol_in(tutorial_third)

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_first.id}/tasks"

    assert_equal 3, last_response_body.count

    assert_includes [tutorial_first.id, nil, tutorial_third.id], last_response_body.first['tutorial_id']
    assert_includes [tutorial_first.id, nil, tutorial_third.id], last_response_body.second['tutorial_id']
    assert_includes [tutorial_first.id, nil, tutorial_third.id], last_response_body.third['tutorial_id']

    # Tutorial second should not be returned since it is for a different stream
    assert_not_equal tutorial_second.id, last_response_body.first['tutorial_id']
    assert_not_equal tutorial_second.id, last_response_body.second['tutorial_id']
    assert_not_equal tutorial_second.id, last_response_body.third['tutorial_id']

    # task def first belongs to tutorial stream first, so either enrolled in that or match all
    assert_includes [tutorial_stream_first.id, nil], last_response_body.first['tutorial_stream_id']
    assert_includes [tutorial_stream_first.id, nil], last_response_body.second['tutorial_stream_id']
    assert_includes [tutorial_stream_first.id, nil], last_response_body.third['tutorial_stream_id']

    # Get the tasks for the first task definition
    get with_auth_token "/api/units/#{unit.id}/task_definitions/#{task_def_third.id}/tasks"

    assert_equal 1, last_response_body.count
    assert_equal project_second.id, last_response_body.first['project_id']
    assert_equal tutorial_second.id, last_response_body.first['tutorial_id']
    assert_equal tutorial_stream_second.id, last_response_body.first['tutorial_stream_id']
    assert_equal task_fourth.id, last_response_body.first['id']
  end
 end
