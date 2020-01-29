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
      tutorial_stream: test_unit.tutorial_streams.first,
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

  def test_group_tasks
    u = Unit.first
    activity_type = FactoryBot.create(:activity_type)
    u.add_tutorial_stream('Group-Tasks-Test', 'group-tasks-test', activity_type)

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

  def test_export_task_definitions_csv
    unit = FactoryBot.create(:unit, with_students: false)
    stream_1 = FactoryBot.create(:tutorial_stream, unit: unit)

    task_defs_csv = CSV.parse unit.task_definitions_csv, headers: true
    task_defs_csv.each do |task_def_csv|
      task_def = unit.task_definitions.find_by(abbreviation: task_def_csv['abbreviation'])
      keys_to_ignore = ['tutorial_stream', 'plagiarism_checks', 'start_week', 'start_day', 'target_week', 'target_day', 'due_week', 'due_day']
      task_def_csv.each do |key, value|
        unless keys_to_ignore.include?(key)
          assert_equal(task_def[key].to_s, value)
        end
      end

      assert_equal task_def.start_week.to_s, task_def_csv['start_week']
      assert_equal task_def.start_day.to_s, task_def_csv['start_day']
      assert_equal task_def.target_week.to_s, task_def_csv['target_week']
      assert_equal task_def.target_day.to_s, task_def_csv['target_day']
      assert_equal task_def.due_week.to_s, task_def_csv['due_week']
      assert_equal task_def.due_day.to_s, task_def_csv['due_day']
      assert_equal task_def.tutorial_stream.present? ? task_def.tutorial_stream.abbreviation : nil, task_def_csv['tutorial_stream']
    end
  end

  def test_export_without_tutorial_stream
    data = {
      code: 'COS10001',
      name: 'Testing in Unit Tests',
      description: 'Test unit',
      teaching_period: TeachingPeriod.find(3)
    }

    unit = Unit.create(data)
    assert_empty unit.task_definitions
    unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{unit.code}-ImportTasksWithoutTutorialStream.csv"))
    assert_not_empty unit.task_definitions

    task_defs_csv = CSV.parse unit.task_definitions_csv, headers: true
    task_defs_csv.each do |task_def_csv|
      assert_nil task_def_csv['tutorial_stream']
    end
  end

  def test_import_without_tutorial_stream
    data = {
      code: 'COS10001',
      name: 'Testing in Unit Tests',
      description: 'Test unit',
      teaching_period: TeachingPeriod.find(3)
    }

    unit = Unit.create(data)
    assert_empty unit.task_definitions
    unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{unit.code}-ImportTasksWithoutTutorialStream.csv"))
    assert_equal 36, unit.task_definitions.count, 'imported all task definitions'

    unit.task_definitions.each do |task_definition|
      assert_nil task_definition.tutorial_stream
    end
  end

  def test_import_with_tutorial_stream
    data = {
      code: 'COS10001',
      name: 'Testing in Unit Tests',
      description: 'Test unit',
      teaching_period: TeachingPeriod.find(3)
    }

    unit = Unit.create(data)
    assert_empty unit.tutorial_streams
    assert_empty unit.task_definitions

    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream = unit.add_tutorial_stream('Import-Tasks', 'import-tasks', activity_type)
    unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{unit.code}-ImportTasksWithTutorialStream.csv"))
    assert_equal 36, unit.task_definitions.count, 'imported all task definitions'

    unit.task_definitions.each do |task_definition|
      assert_equal tutorial_stream, task_definition.tutorial_stream
    end
  end

end
