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

  def test_default_tii_settings
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      tutorial_stream: test_unit.tutorial_streams.first,
      name: 'Test tii settings',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestTiiSettings',
      restrict_status_updates: false,
      upload_requirements: [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 5
        },
        {
          "key" => 'file1',
          "name" => 'Document 2',
          "type" => 'document',
          "tii_check" => false,
          "tii_pct" => 10
        },
        {
          "key" => 'file2',
          "name" => 'Code 1',
          "type" => 'code',
          "tii_check" => true,
          "tii_pct" => 20
        },
        {
          "key" => 'file3',
          "name" => 'Image 3',
          "type" => 'image',
          "tii_check" => true,
          "tii_pct" => 30
        },
        {
          "key" => 'file4',
          "name" => 'Document 4',
          "type" => 'document'
        }
      ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })
    td.save!

    assert td.is_document?(0)
    assert td.is_document?(1)
    refute td.is_document?(2)
    refute td.is_document?(3)
    assert td.is_document?(4)

    assert td.use_tii?(0)
    refute td.use_tii?(1)
    refute td.use_tii?(2)
    refute td.use_tii?(3)
    refute td.use_tii?(4)

    assert_equal 5, td.tii_match_pct(0)
    assert_equal 35, td.tii_match_pct(1) # default
    assert_equal 35, td.tii_match_pct(2)
    assert_equal 35, td.tii_match_pct(3)
    assert_equal 35, td.tii_match_pct(4)

    td.destroy
  end

  def test_group_tasks
    u = FactoryBot.create(:unit)
    activity_type = FactoryBot.create(:activity_type)
    u.add_tutorial_stream('Group-Tasks-Test', 'group-tasks-test', activity_type)

    group_params = {
      name: 'Group Work',
      allow_students_to_create_groups: true,
      allow_students_to_manage_groups: true,
      keep_groups_in_same_class: true
    }

    initial_count = u.task_definitions.count

    group_set = GroupSet.create(group_params)
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
      keys_to_ignore = ['tutorial_stream', 'start_week', 'start_day', 'target_week', 'target_day', 'due_week', 'due_day', 'scorm_enabled', 'scorm_time_delay_enabled', 'scorm_attempt_limit']
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

  def test_cannot_change_group_set_with_submissions
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 3}], task_count: 0

    td = FactoryBot.create :task_definition, unit: unit, group_set: unit.group_sets.first, upload_requirements: [ ], start_date: Time.zone.now + 1.day

    group = unit.groups.first

    p1 = group.projects.first
    t1 = p1.task_for_task_definition(td)

    t1.create_submission_and_trigger_state_change(t1.student, true)

    assert t1.group_submission

    td.group_set = nil

    refute td.valid?
  end

  def test_delete_unneeded_group_submission_on_group_set_change
    # When we change the group setting, and there is some old task interactions
    # make sure group submission details are removed

    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 3}], task_count: 0

    td = FactoryBot.create :task_definition, unit: unit, group_set: unit.group_sets.first, upload_requirements: [ ], start_date: Time.zone.now + 1.day

    group = unit.groups.first

    p1 = group.projects.first
    t1 = p1.task_for_task_definition(td)

    t1.trigger_transition trigger: 'working_on_it', by_user: p1.student

    assert t1.group_submission

    td.group_set = nil

    assert td.valid?
    assert td.save!

    t1.reload

    assert_nil t1.group_submission

    unit.destroy
  end

end
