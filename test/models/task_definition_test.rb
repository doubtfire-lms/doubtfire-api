require 'test_helper'

#
# Contains tests for TaskDefinition model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  def test_default_quality_points
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })
    td.save!

    p = test_unit.active_projects.first

    task = p.task_for_task_definition(td)

    assert task
    assert task.quality_pts = -1

    td.destroy
  end

  def test_default_quality_points
    u = Unit.first

    group_params = {
      name: 'Group Work',
      allow_students_to_create_groups: true,
      allow_students_to_manage_groups: true,
      keep_groups_in_same_class: true
    }

    initial_count = u.task_definitions.count

    group_set = GroupSet.create!(group_params)
    group_set.unit = u
    group_set.save!

    path = Rails.root.join('test_files', 'unit_csv_imports', 'import_group_tasks.csv')
    u.import_tasks_from_csv File.new(path)

    assert_equal 1, group_set.task_definitions.count
    assert_equal initial_count + 1, u.task_definitions.count
  end

  test 'method copy_to success' do
    task_definition = TaskDefinition.first
    unit = Unit.find_by_id(2)
    total_task_definition = TaskDefinition.count
    new_task_definition = task_definition.copy_to(unit)

    assert_equal(TaskDefinition.count, total_task_definition + 1, 'create new task definition success')
    assert_includes(unit.task_definitions.pluck(:id), new_task_definition.id, 'in unit contain new task definition')
    week, day = task_definition.start_week, task_definition.start_day
    assert_equal(new_task_definition.start_date.to_i, unit.date_for_week_and_day(week, day).to_i, 'start date of new task definition correct')
    week, day = task_definition.target_week, task_definition.target_day
    assert_equal(new_task_definition.target_date.to_i, unit.date_for_week_and_day(week, day).to_i, 'target date of new task definition correct')
  end

  test 'validation ensure_no_submissions have error' do
    test_unit = Unit.first
    
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false
    })
    td.save!
    task = Task.create!(
      project_id: 1,
      task_status_id: 1,
      task_definition_id: td.id,
      submission_date: Time.now.utc
    )
    td.tasks << task
    td.group_set_id = 1
    assert !td.valid?
  end

  test 'method move_files_on_abbreviation_change success' do
    td = TaskDefinition.first
    FileUtils.stubs(:mv).returns(true)
    td.send(:move_files_on_abbreviation_change)
  end

  test 'validation check_plagiarism_format have error plagiarism_checks is not array' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: { test: 'test' }.to_json
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('is not in a valid format!')
  end

  test 'validation check_plagiarism_format have error plagiarism_checks is not json' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: "test"
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('is not in a valid format!')
  end

  test 'validation check_plagiarism_format have error plagiarism_checks is array number' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: [1, 2, 3]
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('is not in a valid format!')
  end

  test 'validation check_plagiarism_format have error plagiarism_checks is wrong key' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: [{ test: 1 }]
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('is not in a valid format!')
  end

  test 'validation check_plagiarism_format have type not valid' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: [{ type: 'test', key: 'test', pattern: 'test' }].to_json
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('does not have a valid type')
  end

  test 'validation check_plagiarism_format have pattern contains invalid characters' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: [{ type: 'moss ', key: 'test', pattern: '\/' }].to_json
    })
    assert !td.valid?
    assert td.errors.messages[:plagiarism_checks].first.include?('pattern contains invalid characters')
  end

  test 'validation check_plagiarism_format move to next check' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      plagiarism_checks: [{ type: 'moss ', key: 'test', pattern: 'hello' }].to_json
    })
    assert td.valid?
  end

  test 'validation check_upload_requirements_format have error did not contain array' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      upload_requirements: '',
    })
    assert !td.valid?
    assert td.errors.messages[:upload_requirements].first.include?('Did not contain array.')
  end

  test 'validation check_upload_requirements_format have error array did not contain hashes' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      upload_requirements: [""],
    })
    assert !td.valid?
    assert td.errors.messages[:upload_requirements].first.include?('Array did not contain hashes')
  end

  test 'validation check_upload_requirements_format have error missing a key for item ' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      upload_requirements: [{ key: 'test', name: 'test' }],
    })
    assert !td.valid?
    assert td.errors.messages[:upload_requirements].first.include?('Missing a key for item')
  end

  test 'validation check_upload_requirements_format can not process not yet array' do
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def'
    })
    td.upload_requirements = { key: 'test', name: 'test' }.to_json
    assert !td.valid?
  end

  test 'method clear_related_plagiarism success' do
    td = TaskDefinition.first
    task = Task.create!(
      project_id: 1,
      task_status_id: 1,
      task_definition_id: td.id,
      submission_date: Time.now.utc
    )
    PlagiarismMatchLink.create!(
      task: task,
      other_task: task,
      dismissed: false
    )
    td.send(:clear_related_plagiarism)
    assert_equal(0, PlagiarismMatchLink.count, 'deleted PlagiarismMatchLink')
  end

  test 'method to_csv success return csv content' do
    tds = TaskDefinition.first(2)
    csv_file = TaskDefinition.to_csv(tds)
    assert csv_file.include?(tds[0].name)
    assert csv_file.include?(tds[1].name)
end

  test 'method due_date return end date of unit' do
    td = TaskDefinition.find_by_id(4)
    unit = td.unit
    assert_equal(unit.end_date.to_i, td.due_date.to_i)
  end

  test 'method due_week return empty string' do
    td = TaskDefinition.find_by_id(4)
    td.stubs(:due_date).returns('')
    assert_equal('', td.due_week)
  end

  test 'method due_day return empty string' do
    td = TaskDefinition.find_by_id(4)
    td.stubs(:due_date).returns(nil)
    assert_equal('', td.due_day)
  end

  test 'method task_def_for_csv_row have error failed to save definition due to data error' do
    unit = Unit.first
    TaskDefinition.create!(unit_id: unit.id, name: 'test', abbreviation: true, target_date: 'Sun', start_date: 'Sun', weighting: 5)
    TaskDefinition.any_instance.stubs(:save).raises(StandardError, 'Test')
    time = Time.now
    row = {
      abbreviation: 'test',
      name: 'test',
      target_day: 'Sun',
      target_week: time.strftime('%W'),
      start_week: time.strftime('%W'),
      start_day: 'Sun',
      due_week: time.strftime('%W'),
      due_day: 'Sun',
      weighting: 8,
      description: 'test',
      target_grade: 3,
      upload_requirements: [],
      group_set: ''
    }
    errors = TaskDefinition.task_def_for_csv_row(unit, row)
    assert_equal(nil, errors[0])
    assert_equal(false, errors[1])
    assert_equal('Failed to save definition due to data error.', errors[2])
  end

  test 'method task_def_for_csv_row have error unable to find groupset with name' do
    unit = Unit.last
    time = Time.now
    TaskDefinition.stubs(:find_by).returns(nil)
    TaskDefinition.any_instance.stubs(:valid?).returns(false)
    row = {
      abbreviation: 'test',
      name: 'test',
      target_day: 'Sun',
      target_week: time.strftime('%W'),
      start_week: time.strftime('%W'),
      start_day: 'Sun',
      due_week: time.strftime('%W'),
      due_day: 'Sun',
      weighting: 8,
      description: 'test',
      target_grade: 3,
      upload_requirements: [],
      group_set: 'test'
    }
    errors = TaskDefinition.task_def_for_csv_row(unit, row)
    assert_equal(nil, errors[0])
    assert_equal(false, errors[1])
    assert_equal('Unable to find groupset with name test in unit.', errors[2])
  end

  test 'method task_def_for_csv_row have error when valid' do
    unit = Unit.last
    time = Time.now
    TaskDefinition.stubs(:find_by).returns(nil)
    TaskDefinition.any_instance.stubs(:valid?).returns(false)
    row = {
      abbreviation: 'test',
      name: 'test',
      target_day: 'Sun',
      target_week: time.strftime('%W'),
      start_week: time.strftime('%W'),
      start_day: 'Sun',
      due_week: time.strftime('%W'),
      due_day: 'Sun',
      weighting: 8,
      description: 'test',
      target_grade: 3,
      upload_requirements: []
    }
    errors = TaskDefinition.task_def_for_csv_row(unit, row)
    assert_equal(nil, errors[0])
    assert_equal(false, errors[1])
    assert_equal('', errors[2])
  end

  test 'method is_group_task? return false' do
    td = TaskDefinition.first
    assert_equal(false, td.is_group_task?)
  end

  test 'method is_graded? return false' do
    td = TaskDefinition.first
    assert_equal(false, td.is_graded?)
  end

  test 'method has_stars? return false' do
    td = TaskDefinition.first
    assert_equal(false, td.has_stars?)
  end

  test 'method add_task_sheet success' do
    td = TaskDefinition.first
    FileUtils.expects(:mv)
    td.add_task_sheet(nil)
  end

  test 'method remove_task_sheet success' do
    td = TaskDefinition.first
    FileUtils.expects(:rm)
    td.remove_task_sheet
  end

  test 'method add_task_resources success' do
    td = TaskDefinition.first
    FileUtils.expects(:mv)
    td.add_task_resources(nil)
  end

  test 'method remove_task_resources success' do
    td = TaskDefinition.first
    FileUtils.expects(:rm)
    td.remove_task_resources
  end

  test 'method related_tasks_with_files success' do
    td = TaskDefinition.first
    tasks_with_files = td.related_tasks_with_files
    assert_equal([], tasks_with_files)
  end

  test 'method related_tasks_with_files have group_set_id run success return empty array' do
    unit = Unit.first
    gs = GroupSet.create!({name: 'task_definition_test', unit: unit})
    td = TaskDefinition.create!(unit_id: unit.id, name: 'test', abbreviation: true, target_date: 'Sun', start_date: 'Sun', weighting: 5, group_set_id: gs.id)
    task = Task.create!(task_definition_id: td.id, project_id: Project.first.id, task_status_id: 1)
    Task.any_instance.stubs(:has_pdf).returns(true)
    tasks_with_files = td.related_tasks_with_files
    assert_equal([], tasks_with_files)
  end

  test 'method related_tasks_with_files have group_set_id run success return array tasks' do
    unit = Unit.first
    gs = GroupSet.create!({name: 'task_definition_test', unit: unit})
    group = Group.create!(name: 'test', group_set: gs, tutorial: Tutorial.first, number: 5)
    GroupMembership.create(group: group, project: Project.first)
    td = TaskDefinition.create!(unit_id: unit.id, name: 'test', abbreviation: true, target_date: 'Sun', start_date: 'Sun', weighting: 5, group_set_id: gs.id)
    task = Task.create!(task_definition_id: td.id, project_id: Project.first.id, task_status_id: 1)
    Task.any_instance.stubs(:has_pdf).returns(true)
    tasks_with_files = td.related_tasks_with_files
    assert_equal([task], tasks_with_files)
  end

  test 'method task_sheet_with_abbreviation success return path' do
    td = TaskDefinition.first
    File.expects(:exist?).returns(true)
    path = td.send(:task_sheet_with_abbreviation, 'test')
    assert(path.include?('student_work/COS10001-1/TaskFiles/test.pdf'))
  end

  test 'method task_resources_with_abbreviation success return path' do
    td = TaskDefinition.first
    File.expects(:exist?).returns(true)
    path = td.send(:task_resources_with_abbreviation, 'test')
    assert(path.include?('student_work/COS10001-1/TaskFiles/test.zip'))
  end
end
