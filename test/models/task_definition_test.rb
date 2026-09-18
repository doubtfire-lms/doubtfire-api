require 'test_helper'

#
# Contains tests for TaskDefinition model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  def test_validation_ignores_orphaned_prerequisite_records
    unit = FactoryBot.create(:unit, task_count: 0)
    prerequisite = FactoryBot.create(:task_definition, unit: unit, target_grade: 0)
    dependent = FactoryBot.create(:task_definition, unit: unit, target_grade: 0)
    TaskPrerequisite.create!(
      task_definition: dependent,
      prerequisite: prerequisite,
      task_status_id: TaskStatus.complete.id
    )

    prerequisite.delete

    assert_nothing_raised { dependent.update!(name: 'Updated task definition') }
  end

  def test_unit_can_be_destroyed_when_its_tasks_have_prerequisites
    unit = FactoryBot.create(:unit, task_count: 0)
    prerequisite = FactoryBot.create(:task_definition, unit: unit, target_grade: 0)
    dependent = FactoryBot.create(:task_definition, unit: unit, target_grade: 0)
    task_prerequisite = TaskPrerequisite.create!(
      task_definition: dependent,
      prerequisite: prerequisite,
      task_status_id: TaskStatus.complete.id
    )

    unit.destroy!

    assert_not TaskDefinition.exists?(prerequisite.id)
    assert_not TaskDefinition.exists?(dependent.id)
    assert_not TaskPrerequisite.exists?(task_prerequisite.id)
  end

  def test_overseer_requires_a_submission_history_upload
    task_definition = FactoryBot.build(
      :task_definition,
      assessment_enabled: true,
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => false }
      ]
    )

    assert_not task_definition.valid?
    assert_includes task_definition.errors[:upload_requirements],
                    'must include at least one file in submission history when Overseer is enabled'
  end

  def test_overseer_accepts_a_submission_history_upload
    task_definition = FactoryBot.build(
      :task_definition,
      assessment_enabled: true,
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => true }
      ]
    )

    task_definition.validate
    assert_empty task_definition.errors[:upload_requirements]
  end

  def test_normalizes_duplicate_and_out_of_order_upload_requirement_keys
    task_definition = FactoryBot.build(
      :task_definition,
      upload_requirements: [
        { 'key' => 'file1', 'name' => 'main.rb', 'type' => 'code' },
        { 'key' => 'file1', 'name' => 'output.png', 'type' => 'image' },
        { 'key' => 'file5', 'name' => 'report.pdf', 'type' => 'document' }
      ]
    )

    task_definition.save!
    task_definition.reload

    assert_equal %w[file0 file1 file2], task_definition.upload_requirements.pluck('key')
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

  def test_upload_requirements_allow_zip
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      tutorial_stream: test_unit.tutorial_streams.first,
      name: 'Test zip requirement',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestZipReq',
      restrict_status_updates: false,
      upload_requirements: [
        {
          "key" => 'file0',
          "name" => 'Source Zip',
          "type" => 'zip'
        }
      ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })

    assert td.valid?, td.errors.full_messages.join(', ')
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
    task_def_with_steps = unit.task_definitions.first
    task_def_with_steps.overseer_steps.create!(
      name: 'compile',
      description: 'Compile the submission',
      display_name: 'Compile',
      display_description: 'Compile step',
      run_command: 'make test',
      timeout: 45,
      sort_order: 0,
      step_type: 'run',
      partial_output_diff: true,
      stdin_input_file: 'stdin.txt',
      expected_output_file: 'expected.txt',
      feedback_message: 'Compilation failed',
      status_on_success_id: TaskStatus.complete.id,
      status_on_failure_id: TaskStatus.fix_and_resubmit.id,
      halt_on_success: false,
      halt_on_failure: true,
      show_expected_output: true,
      show_stdin: false,
      show_stdout: true,
      enabled: true
    )

    task_defs_csv = CSV.parse unit.task_definitions_csv, headers: true
    task_defs_csv.each do |task_def_csv|
      task_def = unit.task_definitions.find_by(abbreviation: task_def_csv['abbreviation'])
      keys_to_ignore = %w[tutorial_stream start_week start_day target_week target_day due_week due_day upload_requirements task_prerequisites discussion_prompts overseer_steps]
      task_def_csv.each do |key, value|
        unless keys_to_ignore.include?(key)
          assert_equal(task_def[key].to_s, value)
        end
      end

      assert_equal task_def.upload_requirements.to_json, task_def_csv['upload_requirements']
      assert_equal task_def.start_week.to_s, task_def_csv['start_week']
      assert_equal task_def.start_day.to_s, task_def_csv['start_day']
      assert_equal task_def.target_week.to_s, task_def_csv['target_week']
      assert_equal task_def.target_day.to_s, task_def_csv['target_day']
      assert_equal task_def.due_week.to_s, task_def_csv['due_week']
      assert_equal task_def.due_day.to_s, task_def_csv['due_day']
      assert_equal task_def.tutorial_stream.present? ? task_def.tutorial_stream.abbreviation : nil, task_def_csv['tutorial_stream']

      prerequisites = task_def.task_prerequisites.map do |tp|
        prereq = TaskDefinition.find(tp.prerequisite_id)
        {
          abbreviation: prereq.abbreviation,
          task_status_id: tp.task_status_id
        }
      end.to_json

      assert_equal prerequisites, task_def_csv['task_prerequisites']

      overseer_steps = task_def.overseer_steps.map do |step|
        {
          'name' => step.name,
          'description' => step.description,
          'display_name' => step.display_name,
          'display_description' => step.display_description,
          'run_command' => step.run_command,
          'timeout' => step.timeout,
          'sort_order' => step.sort_order,
          'step_type' => step.step_type,
          'partial_output_diff' => step.partial_output_diff,
          'stdin_input_file' => step.stdin_input_file,
          'expected_output_file' => step.expected_output_file,
          'feedback_message' => step.feedback_message,
          'status_on_success' => TaskStatus.find_by(id: step.status_on_success_id)&.status_key&.to_s,
          'status_on_failure' => TaskStatus.find_by(id: step.status_on_failure_id)&.status_key&.to_s,
          'halt_on_success' => step.halt_on_success,
          'halt_on_failure' => step.halt_on_failure,
          'show_expected_output' => step.show_expected_output,
          'show_stdin' => step.show_stdin,
          'show_stdout' => step.show_stdout,
          'enabled' => step.enabled
        }
      end

      assert_equal overseer_steps, JSON.parse(task_def_csv['overseer_steps'])
    end
  end

  def test_import_overseer_steps_from_csv_fixture
    target_unit = Unit.create!(
      code: 'CSVSTEP1',
      name: 'CSV Import With Overseer Steps',
      description: 'Import target',
      teaching_period: TeachingPeriod.find(3)
    )

    result = target_unit.import_tasks_from_csv(
      File.open(Rails.root.join("test_files/COS10001-ImportTasksWithOverseerSteps.csv"))
    )

    assert_empty result[:errors], result

    imported_task_def = target_unit.task_definitions.find_by(abbreviation: '1.1P')
    assert_not_nil imported_task_def
    assert_equal 1, imported_task_def.overseer_steps.count

    imported_step = imported_task_def.overseer_steps.first
    assert_equal 'Step 1', imported_step.name
    assert_equal 'Step 1 student', imported_step.display_name
    assert_equal 'b64:IyEvYmluL2Jhc2gKCmVjaG8gIkhlbGxvIHdvcmxkISI', imported_step.run_command
    assert_equal 30, imported_step.timeout
    assert_equal 'status_check', imported_step.step_type
    assert_nil imported_step.status_on_success_id
    assert_nil imported_step.status_on_failure_id
    assert_nil imported_step.partial_output_diff
    assert_nil imported_step.stdin_input_file
    assert_nil imported_step.expected_output_file
    assert_nil imported_step.feedback_message
    assert_nil imported_step.halt_on_success
    assert_nil imported_step.halt_on_failure
    assert imported_step.show_expected_output
    assert_nil imported_step.show_stdin
    assert imported_step.show_stdout
    assert imported_step.enabled
  end

  def test_import_does_not_skip_task_name_containing_name
    target_unit = Unit.create!(
      code: 'CSVNAME1',
      name: 'CSV Import With Name Substring',
      description: 'Import target',
      teaching_period: TeachingPeriod.find(3)
    )

    csv = CSV.generate do |rows|
      rows << TaskDefinition.required_csv_columns
      rows << [
        'Coin Clash (Tournament Mini-Project)',
        'D4',
        'Build an adversarial game agent.',
        1,
        0,
        false,
        0,
        false,
        90,
        false,
        false,
        false,
        false,
        0,
        nil,
        [{ key: 'file0', name: 'coin_clash.rb', type: 'code' }].to_json,
        1,
        'Tue',
        1,
        'Tue',
        1,
        'Tue',
        nil,
        false,
        [].to_json,
        [].to_json
      ]
    end

    file = Tempfile.new(['task-definitions', '.csv'])
    file.write(csv)
    file.close

    result = target_unit.import_tasks_from_csv(file.path)

    assert_empty result[:errors], result
    assert target_unit.task_definitions.exists?(abbreviation: 'D4')
  ensure
    file&.unlink
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
  ensure
    unit.destroy
  end

  def test_upload_req_format
    u = FactoryBot.create :unit, task_count: 0, with_students: false
    td = FactoryBot.create :task_definition, unit: u, upload_requirements: [], start_date: Time.zone.now + 1.day

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]
    assert td.valid?

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document'
        }
      ]
    assert td.valid?, 'tii check and pct not required'

    td.upload_requirements =
      [
        {
          "name" => 'Document 1',
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]

    assert_not td.valid?, 'missing key'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'missing name'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'missing type'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document',
          "other" => true,
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'unknown key'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'other',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'unknown type'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document',
          "tii_check" => 'test',
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'tii_check not boolean'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => 'Document 1',
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 'test'
        }
      ]
    assert_not td.valid?, 'tii_pct not integer'

    td.upload_requirements =
      [
        {
          "key" => 'file0',
          "name" => "\tnot a filename",
          "type" => 'document',
          "tii_check" => true,
          "tii_pct" => 5
        }
      ]
    assert_not td.valid?, 'name not valid filename'
  ensure
    u.destroy
  end

  def test_overdue_tasks_update_to_assess_in_portfolio
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)
    unit.update(mark_late_submissions_as_assess_in_portfolio: false)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    td1.update(assess_in_portfolio_only: false)
    td2.update(assess_in_portfolio_only: false)

    student = unit.projects.first

    task1 = student.task_for_task_definition(td1)
    task2 = student.task_for_task_definition(td2)

    task1.comments.destroy_all
    task2.comments.destroy_all

    task1.update(task_status_id: TaskStatus.time_exceeded.id)

    task2.update(task_status_id: TaskStatus.feedback_exceeded.id)

    task1.reload
    task2.reload

    assert_equal TaskStatus.time_exceeded, task1.task_status
    assert_equal TaskStatus.feedback_exceeded, task2.task_status

    td1.update(assess_in_portfolio_only: true)

    task1.reload
    task2.reload

    assert_equal TaskStatus.assess_in_portfolio, task1.task_status, "Time exceeded task should have moved to assess in portfolio"
    assert_equal TaskStatus.feedback_exceeded, task2.task_status, "Feedback exceeded task should not have changes status"

    missing_aip_status_error = "Assess in Portfolio status comment missing"

    lc = task1.last_comment
    assert_not lc.nil?, missing_aip_status_error
    assert_equal TaskStatus.assess_in_portfolio.name, lc.comment, missing_aip_status_error
    assert_equal TaskStatus.assess_in_portfolio, lc.task_status, missing_aip_status_error
    lc.destroy!

    assert_equal TaskStatus.feedback_exceeded, task2.task_status

    td2.update(assess_in_portfolio_only: true)
    task2.reload

    assert_equal TaskStatus.feedback_exceeded, task2.task_status

    lc = task2.last_comment
    assert_nil lc, "Task 2 should not have been moved to assess in portfolio state"
  end

  def test_cant_disable_aip_only_while_aip_tasks_exist
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)

    td1 = unit.task_definitions.first

    td1.update(assess_in_portfolio_only: true)

    student = unit.projects.first

    task1 = student.task_for_task_definition(td1)

    task1.update(task_status_id: TaskStatus.assess_in_portfolio.id)

    # Ensure we can update a task definition that as AIP disabled, with AIP tasks
    due_date = td1.due_date + 1.week
    td1.update(due_date: due_date)
    assert td1.valid?, "Task definition should be able to be updated"

    # Enable assess in portfolio
    td1.update(assess_in_portfolio_only: true)
    assert td1.valid?

    # Ensure we can't disable assess in portfolio once we have AIP tasks
    td1.assess_in_portfolio_only = false
    assert_not td1.valid?, '"Assess in Portfolio Only" cannot be disabled while tasks are in the Assess in Portfolio state'
    assert_includes td1.errors[:assess_in_portfolio_only], 'cannot be disabled while tasks are in the Assess in Portfolio state'
  end

  def test_reset_overdue_tasks_on_due_date_change
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 3)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second
    td3 = unit.task_definitions.third

    td3.update!(assess_in_portfolio_only: true)

    student = unit.projects.first

    task1 = student.task_for_task_definition(td1)
    task2 = student.task_for_task_definition(td2)
    task3 = student.task_for_task_definition(td3)

    task1.update!(task_status_id: TaskStatus.time_exceeded.id, submission_date: Time.zone.now)
    task2.update!(task_status_id: TaskStatus.assess_in_portfolio.id, submission_date: Time.zone.now)
    task3.update!(task_status_id: TaskStatus.assess_in_portfolio.id, submission_date: Time.zone.now)

    # Setting the due date back one day shouldn't reset submissions
    td1.update!(due_date: Time.zone.today - 1.day)
    td2.update!(due_date: Time.zone.today - 1.day)
    td3.update!(due_date: Time.zone.today - 1.day)

    task1.reload
    task2.reload
    task3.reload

    assert TaskStatus.time_exceeded, task1.task_status
    assert TaskStatus.time_exceeded, task2.task_status
    assert TaskStatus.assess_in_portfolio, task3.task_status

    # Setting the due date after the task submission dates should reset task statuses
    td1.update!(due_date: Time.zone.today + 2.days)
    td2.update!(due_date: Time.zone.today + 2.days)
    td3.update!(due_date: Time.zone.today + 2.days)

    task1.reload
    task2.reload
    task3.reload

    assert TaskStatus.ready_for_feedback, task1.task_status
    assert TaskStatus.ready_for_feedback, task2.task_status

    # Assess in portfolio only task should not be reset
    assert TaskStatus.assess_in_portfolio, task3.task_status

    # Ensure status comments were created
    lc1 = task1.comments.last
    lc2 = task2.comments.last

    assert_not lc1.nil?
    assert_not lc2.nil?

    assert TaskStatus.ready_for_feedback.name, lc1.comment
    assert TaskStatus.ready_for_feedback.name, lc2.comment
  end
end
