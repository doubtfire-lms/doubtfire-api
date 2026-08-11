require 'test_helper'
require 'grade_helper'
require './lib/helpers/database_populator'
require 'pdf-reader'

class UnitModelTest < ActiveSupport::TestCase
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  setup do
    @unit = FactoryBot.create :unit, code: 'COS10001', with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0, teaching_period: TeachingPeriod.find(3)
    @unit.add_tutorial_stream('Import-Tasks', 'import-tasks', ActivityType.first)
    @unit.update(portfolio_auto_generation_date: @unit.end_date - 1.day)
  end

  teardown do
    @unit.destroy
  end

  def test_sync_unit
    import_settings = {
      replace_existing_campus: false,
      replace_existing_tutorial: false,
      merge_duplicate_students: false
    }

    student = FactoryBot.create :user, :student
    campus2 = FactoryBot.create :campus

    student_list = [
      {
        unit_code: 'COS10001',
        username: student.username,
        student_id: student.student_id,
        first_name: student.first_name,
        last_name: student.last_name,
        nickname: student.nickname,
        email: student.email,
        tutorials: [],
        enrolled: true,
        campus: Campus.first.abbreviation
      }
    ]

    result = {
      success: [],
      ignored: [],
      errors: []
    }

    @unit.sync_enrolment_with(student_list, import_settings, result)

    assert_equal 0, result[:ignored].count, result.inspect
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 1, result[:success].count, result.inspect

    result[:success].clear

    student_list[0][:campus] = campus2.abbreviation

    @unit.sync_enrolment_with(student_list, import_settings, result)

    assert_equal 1, result[:ignored].count, result.inspect
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 0, result[:success].count, result.inspect

    assert_equal 1, @unit.projects.count
    assert_equal Campus.first, @unit.projects.first.campus, result.inspect

    result[:ignored].clear

    import_settings[:replace_existing_campus] = true

    @unit.sync_enrolment_with(student_list, import_settings, result)

    assert_equal 0, result[:ignored].count, result.inspect
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 1, result[:success].count, result.inspect

    assert_equal @unit.projects.first.campus, campus2, result.inspect

    result[:success].clear

    @unit.projects.first.destroy
    campus2.destroy!
  end

  def test_sync_unit_merge_duplicate_students
    import_settings = {
      replace_existing_campus: false,
      replace_existing_tutorial: true,
      merge_duplicate_students: true
    }

    student = FactoryBot.create :user, :student

    tutorial_stream1 = @unit.tutorial_streams.first
    tutorial_stream2 = FactoryBot.create(:tutorial_stream, unit: @unit)

    tutorial1 = FactoryBot.create :tutorial, unit: @unit, campus: Campus.first, tutorial_stream: tutorial_stream1
    tutorial2 = FactoryBot.create :tutorial, unit: @unit, campus: Campus.first, tutorial_stream: tutorial_stream2

    student_list = [
      {
        unit_code: 'COS10001',
        username: student.username,
        student_id: student.student_id,
        first_name: student.first_name,
        last_name: student.last_name,
        nickname: student.nickname,
        email: student.email,
        tutorials: [tutorial1.abbreviation],
        enrolled: true,
        campus: Campus.first.abbreviation
      },
      {
        unit_code: 'COS10001',
        username: student.username,
        student_id: student.student_id,
        first_name: student.first_name,
        last_name: student.last_name,
        nickname: student.nickname,
        email: student.email,
        tutorials: [tutorial2.abbreviation],
        enrolled: true,
        campus: Campus.first.abbreviation
      }
    ]

    result = {
      success: [],
      ignored: [],
      errors: []
    }

    @unit.sync_enrolment_with(student_list, import_settings, result)

    assert_equal 1, result[:ignored].count, result.inspect
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 1, result[:success].count, result.inspect

    assert_equal 2, @unit.tutorials.count

    project = @unit.projects.first
    assert project.valid?

    # Ensure that tutorials from both rows were merged and student was enrolled into each
    assert project.enrolled_in?(tutorial1)
    assert project.enrolled_in?(tutorial2)

    @unit.projects.first.destroy
    tutorial1.destroy!
    tutorial2.destroy!
    tutorial_stream2.destroy!
  end

  def test_import_tasks_worked
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files', "#{@unit.code}-Tasks.csv"))
    assert_equal 37, @unit.task_definitions.count, 'imported all task definitions'
  end

  def test_import_task_files
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files', "#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files', "#{@unit.code}-Tasks.zip")

    @unit.task_definitions.each do |td|
      assert File.exist?(td.task_sheet), "#{td.abbreviation} task sheet missing"
    end

    assert File.exist? @unit.task_definitions.first.task_resources

    # extra checks to ensure the filename matching behavior is correct (longest match)
    td = @unit.task_definitions.find_by(abbreviation: "T1")
    reader = PDF::Reader.new(td.task_sheet)
    assert reader.pages[0].text.include? "Task sheet for task T1!"

    td = @unit.task_definitions.find_by(abbreviation: "T10")
    reader = PDF::Reader.new(td.task_sheet)
    assert reader.pages[0].text.include? "Task sheet for task T10!"
  end

  def test_rollover_of_task_files
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files', "#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files', "#{@unit.code}-Tasks.zip")

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    unit2.task_definitions.each do |td|
      assert File.exist?(td.task_sheet), 'task sheet is absent'
    end

    assert File.exist?(unit2.task_definitions.first.task_resources), 'task resource is absent'

    unit2.destroy
  end

  def test_rollover_of_learning_summary
    lsr = FactoryBot.create(:task_definition, unit: @unit, upload_requirements: [{'key' => 'file0','name' => 'LSR','type' => 'document'}])
    assert lsr.valid?, lsr.errors.full_messages
    @unit.draft_task_definition = lsr
    @unit.save

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert_not_nil unit2.draft_task_definition
    refute_equal lsr, unit2.draft_task_definition

    unit2.destroy
  end

  def test_rollover_of_portfolio_generation
    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert unit2.portfolio_auto_generation_date.present?
    assert unit2.portfolio_auto_generation_date > unit2.start_date && unit2.portfolio_auto_generation_date < unit2.end_date

    unit2.destroy
  end

  def test_rollover_of_group_tasks
    unit = FactoryBot.create(:unit,
      code: 'SIT102',
      teaching_period: TeachingPeriod.find(3),
      group_sets: 1,
      student_count: 2,
      task_count: 1,
      groups: [ { gs: 0, students: 2} ],
      group_tasks: [ { idx: 0, gs: 0 }] )

    unit2 = unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert_equal 1, unit2.group_sets.count
    assert_not_equal unit2.group_sets.first, unit.group_sets.first
    assert unit2.task_definitions.first.is_group_task?, unit2.task_definitions.inspect

    unit.destroy
    unit2.destroy
  end

  def test_rollover_of_communication_sets
    task_definition = FactoryBot.create(:task_definition, unit: @unit, tutorial_stream: @unit.tutorial_streams.first)
    communication_set = @unit.communication_sets.create!(name: 'At Risk Follow Up', active: true)
    communication_set.communication_set_schedules.create!(
      name: 'Weekly follow up',
      active: true,
      anchor_week: 1,
      anchor_day: 'Monday',
      hour: 9,
      minute: 30,
      timezone: 'UTC',
      recurrence: 'weekly',
      interval: 1,
      last_run_at: Time.zone.now,
      last_enqueued_at: Time.zone.now
    )
    communication_rule = communication_set.communication_rules.create!(
      name: 'Not started',
      operator: 'and',
      position: 0,
      send_log_to_convenors: true,
      active: true
    )
    communication_rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: task_definition,
      task_statuses: ['not_started']
    )
    communication_rule.communication_conditions.create!(
      type: 'TutorialStreamEnrolmentCondition',
      operator: 'enrolled_in',
      tutorial_stream: @unit.tutorial_streams.first
    )
    communication_rule.communication_actions.create!(
      type: 'EmailStudentAction',
      subject: 'Please start {{unit.code}}',
      body: 'Hello {{student.first_name}}'
    )

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert_equal 1, unit2.communication_sets.count
    new_set = unit2.communication_sets.first
    assert_not_equal communication_set.id, new_set.id
    assert_equal 'At Risk Follow Up', new_set.name
    assert_equal true, new_set.active

    assert_equal 1, new_set.communication_set_schedules.count
    new_schedule = new_set.communication_set_schedules.first
    assert_not_equal communication_set.communication_set_schedules.first.id, new_schedule.id
    assert_equal 'Weekly follow up', new_schedule.name
    assert_equal 'weekly', new_schedule.recurrence
    assert_nil new_schedule.last_run_at
    assert_nil new_schedule.last_enqueued_at

    assert_equal 1, new_set.communication_rules.count
    new_rule = new_set.communication_rules.first
    assert_not_equal communication_rule.id, new_rule.id
    assert_equal 'Not started', new_rule.name
    assert_equal true, new_rule.send_log_to_convenors

    new_task_definition = unit2.task_definitions.find_by!(abbreviation: task_definition.abbreviation)
    task_condition = new_rule.communication_conditions.find_by!(type: 'TaskDefinitionStatusCondition')
    assert_equal new_task_definition, task_condition.task_definition
    assert_equal ['not_started'], task_condition.task_statuses

    new_tutorial_stream = unit2.tutorial_streams.find_by!(abbreviation: @unit.tutorial_streams.first.abbreviation)
    stream_condition = new_rule.communication_conditions.find_by!(type: 'TutorialStreamEnrolmentCondition')
    assert_equal new_tutorial_stream, stream_condition.tutorial_stream

    assert_equal 1, new_rule.communication_actions.count
    assert_equal 'Please start {{unit.code}}', new_rule.communication_actions.first.subject

    unit2.destroy
  end

  def test_rollover_of_tasks_have_same_start_week_and_day
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert_equal 3, @unit.teaching_period_id
    assert_equal 2, unit2.teaching_period_id

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by(abbreviation: td.abbreviation)

      assert_equal td.start_day, td2.start_day, "#{td.abbreviation} not on same day"
      assert_equal td.start_week, td2.start_week, "#{td.abbreviation} not in same week"
    end

    unit2.destroy!
  end

  def test_rollover_of_tasks_have_same_target_week_and_day
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.target_day, td2.target_day, "#{td.abbreviation} not on same day"
      assert_equal td.target_week, td2.target_week, "#{td.abbreviation} not targetting same week"
    end

    unit2.destroy!
  end

  def test_rollover_assess_in_portfolio
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1)
    td = unit.task_definitions.first

    # Test with both true
    unit.update!(mark_late_submissions_as_assess_in_portfolio: true)
    td.update!(assess_in_portfolio_only: true)

    unit2 = unit.rollover(TeachingPeriod.find(2), nil, nil, nil)
    td2 = unit2.task_definitions.first

    assert_equal true, unit2.mark_late_submissions_as_assess_in_portfolio, "Rollover must copy over unit mark_late_submissions_as_assess_in_portfolio attribute"
    assert_equal true, td2.assess_in_portfolio_only, "Rollover must copy over task definition assess_in_portfolio_only attribute"

    unit2.destroy!

    # Test with both false (in case theyre true by default)
    unit.update!(mark_late_submissions_as_assess_in_portfolio: false)
    td.update!(assess_in_portfolio_only: false)

    unit.reload
    td.reload

    unit3 = unit.rollover(TeachingPeriod.find(2), nil, nil, nil)
    td3 = unit3.task_definitions.first

    assert_equal false, unit3.mark_late_submissions_as_assess_in_portfolio, "Rollover must copy over unit mark_late_submissions_as_assess_in_portfolio attribute"
    assert_equal false, td3.assess_in_portfolio_only, "Rollover must copy over task definition assess_in_portfolio_only attribute"

    unit3.destroy!
  end

  def test_rollover_of_discussion_prompts
    unit = FactoryBot.create(:unit, with_students: false, task_count: 4)
    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    DiscussionPrompt.create!({
                               task_definition: td1,
                               content: 'Discuss pointers and references',
                               priority: 1
                             })

    DiscussionPrompt.create!({
                               task_definition: td1,
                               content: 'Discuss object oriented programming',
                               priority: 2
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Discuss use of AI',
                               priority: 3
                             })

    unit2 = unit.rollover(TeachingPeriod.find(2), nil, nil, nil)

    new_td1 = unit2.task_definitions.first
    new_td2 = unit2.task_definitions.second

    assert_equal 2, new_td1.discussion_prompts.count
    assert_equal 1, new_td2.discussion_prompts.count

    new_prompt1 = new_td1.discussion_prompts.first
    new_prompt2 = new_td1.discussion_prompts.second
    new_prompt3 = new_td2.discussion_prompts.first

    assert_not_nil new_prompt1, "Discussion prompt should be duplicated in rollover"
    assert_not_nil new_prompt2, "Discussion prompt should be duplicated in rollover"
    assert_not_nil new_prompt3, "Discussion prompt should be duplicated in rollover"

    assert_equal new_prompt1.task_definition.id, new_td1.id
    assert_equal new_prompt1.content, 'Discuss pointers and references'
    assert_equal new_prompt1.priority, 1

    assert_equal new_prompt2.task_definition.id, new_td1.id
    assert_equal new_prompt2.content, 'Discuss object oriented programming'
    assert_equal new_prompt2.priority, 2

    assert_equal new_prompt3.task_definition.id, new_td2.id
    assert_equal new_prompt3.content, 'Discuss use of AI'
    assert_equal new_prompt3.priority, 3
  end

  def test_rollover_of_overseer_steps
    unit = FactoryBot.create(:unit, with_students: false, task_count: 2)
    td = unit.task_definitions.first

    td.overseer_steps.create!(
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

    unit2 = unit.rollover(TeachingPeriod.find(2), nil, nil, nil)
    new_td = unit2.task_definitions.find_by!(abbreviation: td.abbreviation)
    new_step = new_td.overseer_steps.first

    assert_equal 1, new_td.overseer_steps.count
    assert_not_nil new_step, 'Overseer step should be duplicated in rollover'
    assert_equal new_td.id, new_step.task_definition_id
    assert_equal 'compile', new_step.name
    assert_equal 'Compile the submission', new_step.description
    assert_equal 'Compile', new_step.display_name
    assert_equal 'Compile step', new_step.display_description
    assert_equal 'make test', new_step.run_command
    assert_equal 45, new_step.timeout
    assert_equal 0, new_step.sort_order
    assert_equal 'run', new_step.step_type
    assert_equal true, new_step.partial_output_diff
    assert_equal 'stdin.txt', new_step.stdin_input_file
    assert_equal 'expected.txt', new_step.expected_output_file
    assert_equal 'Compilation failed', new_step.feedback_message
    assert_equal TaskStatus.complete.id, new_step.status_on_success_id
    assert_equal TaskStatus.fix_and_resubmit.id, new_step.status_on_failure_id
    assert_equal false, new_step.halt_on_success
    assert_equal true, new_step.halt_on_failure
    assert_equal true, new_step.show_expected_output
    assert_equal false, new_step.show_stdin
    assert_equal true, new_step.show_stdout
    assert_equal true, new_step.enabled
  end

  def test_rollover_of_task_prerequisites
    unit = FactoryBot.create(:unit, with_students: false, task_count: 4)
    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    td3 = unit.task_definitions.third
    td4 = unit.task_definitions.fourth

    [td1, td2, td3, td4].each do |td|
      td.update(
        target_grade: 0, # Pass
        start_date: Time.zone.today - 2.weeks,
        target_date: Time.zone.today + 1.week
      )
    end

    prerequisite1 = TaskPrerequisite.create!(
      task_definition: td1,
      prerequisite: td2,
      task_status_id: TaskStatus.discuss.id
    )

    assert prerequisite1.valid?

    prerequisite2 = TaskPrerequisite.create!(
      task_definition: td3,
      prerequisite: td4,
      task_status_id: TaskStatus.complete.id
    )

    assert prerequisite2.valid?

    unit2 = unit.rollover(TeachingPeriod.find(2), nil, nil, nil)

    new_td1 = unit2.task_definitions.first
    new_td2 = unit2.task_definitions.second
    new_prerequisite = new_td1.task_prerequisites.first

    assert_not_nil new_prerequisite, "Task prerequisites should be duplicated in rollover"
    assert_equal new_prerequisite.task_definition.id, new_td1.id, "New Task Prerequisite's task definition should match new task definition"
    assert_equal new_prerequisite.prerequisite.id, new_td2.id
    assert_equal new_prerequisite.task_status_id,  prerequisite1.task_status_id

    prerequisite_td = new_td1.prerequisites.first
    assert_equal prerequisite_td.id, new_td2.id

    new_td3 = unit2.task_definitions.third
    new_td4 = unit2.task_definitions.fourth
    new_prerequisite2 = new_td3.task_prerequisites.first

    assert_not_nil new_prerequisite2, "Task prerequisites should be duplicated in rollover"
    assert_equal new_prerequisite2.task_definition.id, new_td3.id, "New Task Prerequisite's task definition should match new task definition"
    assert_equal new_prerequisite2.prerequisite.id, new_td4.id
    assert_equal new_prerequisite2.task_status_id, new_prerequisite2.task_status_id

    prerequisite_td2 = new_td3.prerequisites.first
    assert_equal prerequisite_td2.id, new_td4.id
  end

  def test_updating_unit_dates_propogates_to_tasks
    @unit.teaching_period = nil
    @unit.save!

    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    pre_update_details = @unit.task_definitions.map{|td| { id: td.id, start_week: td.start_week, target_week: td.target_week, due_week: td.due_week } }

    @unit.start_date = @unit.start_date + 1.week
    @unit.save!

    @unit.reload

    pre_update_details.each do |data|
      td = @unit.task_definitions.find(data[:id])
      td.reload

      assert_equal data[:start_week], td.start_week, "start week for #{td.abbreviation} -- should be #{data[:start_week]} was #{td.start_week}"
      assert_equal data[:target_week], td.target_week, "target week for #{td.abbreviation} -- should be #{data[:target_week]} was #{td.target_week}"
      assert_equal data[:due_week], td.due_week, "due week for #{td.abbreviation} -- should be #{data[:due_week]} was #{td.due_week}"
    end
  end

  test 'rollover of tasks have same due week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by(abbreviation: td.abbreviation)
      assert_equal td.due_day, td2.due_day, "#{td.abbreviation} not on same day"
      assert_equal td.due_week, td2.due_week, "#{td.abbreviation} not due same week"
    end
  end

  def test_student_query
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)

    assert_empty unit.projects
    project = FactoryBot.create(:project, unit: unit, campus: campus)
    assert_equal 1, unit.projects.count


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

    projects = unit.student_query(true)

    assert_equal unit.projects.count, projects.count
    assert_equal 1, projects.count

    # Check returned project
    assert_equal project.id, projects.first[:id]
    assert_equal project.enrolled, projects.first[:enrolled]

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.first[:tutorial_enrolments].count

    # Now test with project without tutorial enrolments
    project2 = FactoryBot.create(:project, unit: unit, campus: campus)
    assert_equal 2, unit.projects.count

    project2.tutorial_enrolments.destroy

    projects = unit.student_query(true)

    assert_equal unit.projects.count, projects.count
    assert_equal 2, projects.count

    # Check returned project
    assert projects.select{|p| p[:id] == project2.id}.first.present?

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.last[:tutorial_enrolments].count

    unit.tutorial_streams.each do |s|
      unit.projects.each do |p|
        proj_tute_enrolment = p.tutorial_enrolment_for_stream(s)
        data_tute_enrolment = projects.select{|ps| ps[:id] == p.id}.first[:tutorial_enrolments].select{|te| te[:stream_abbr] == s.abbreviation}.map{|te| te[:tutorial_id]}.first

        # if there is a enrolment for this project...
        if proj_tute_enrolment.present?
          # check that it matches the data returned
          assert_equal proj_tute_enrolment.tutorial_id, data_tute_enrolment
        else
          # check that the data returned nil for this stream
          assert_nil data_tute_enrolment
        end
      end
    end
  end

  def check_task_completion_csv unit, col_count = nil
    csv_str = unit.task_completion_csv

    CSV.parse(csv_str,
              headers: true,
              return_headers: false,
              header_converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')&.downcase }],
              converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') }]).each do |entry|

      assert_equal(col_count, entry.length, entry.inspect) unless col_count.nil?

      user = User.find_by(username: entry['username'])
      assert user.present?, entry.inspect

      project = unit.active_projects.find_by(user_id: user.id)

      # Test basic details
      assert_equal project.student.username, entry['username'], entry.inspect
      if project.student.student_id.present?
        assert_equal project.student.student_id, entry['student id'], entry.inspect
      else
        assert_nil entry['student id'], entry.inspect
      end
      assert_equal project.student.email, entry['email'], entry.inspect

      # Test task status
      unit.task_definitions.each do |td|
        task = project.task_for_task_definition(td)
        assert_equal task.task_status.name, entry[td.abbreviation.downcase], "#{td.abbreviation} --> #{entry.inspect}"

        assert_equal(task.quality_pts.to_s, entry["#{td.abbreviation.downcase} stars"], "#{td.abbreviation} stars --> #{entry.inspect}") if td.has_stars? && task.quality_pts != -1
        if task.grade.present?
          assert_equal(GradeHelper.short_grade_for(task.grade), entry["#{td.abbreviation.downcase} grade"], "#{td.abbreviation} --> #{entry.inspect}") if td.is_graded?
        else
          assert_nil(entry["#{td.abbreviation.downcase} grade"], "#{td.abbreviation} --> #{entry.inspect}") if td.is_graded?
        end
        assert_equal(task.contribution_pts, (entry["#{td.abbreviation.downcase} contribution"].nil? ? 3 : Integer(entry["#{td.abbreviation.downcase} contribution"])), "#{td.abbreviation} contrib --> #{entry.inspect}") if td.is_group_task?
      end

      # Test tutorial streams
      unit.tutorial_streams.each do |ts|
        if project.tutorial_for_stream(ts).present?
          assert_equal project.tutorial_for_stream(ts).abbreviation, entry[ts.abbreviation.downcase], {entry: entry.inspect, stream: ts.abbreviation, proj_tut: project.tutorial_for_stream(ts)}
        else
          assert_nil entry[ts.abbreviation.downcase], {entry: entry.inspect, stream: ts.abbreviation, proj_tut: project.tutorial_for_stream(ts)}
        end
      end
    end
  end

  def test_task_completion_csv
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:3, student_count:8, unenrolled_student_count: 1, part_enrolled_student_count: 2, set_one_of_each_task: true

    unit.task_definitions.each do |td|
      unit.projects.each do |student|
        task = student.task_for_task_definition(td)
        tutor = student.tutor_for(td)

        DatabasePopulator.assess_task(student, task, tutor, TaskStatus.all.sample, td.start_date + 1.week)
      end
    end

    # 18 = 9 general + 2 streams + 3 task defs + 1 group details + 1 stars + 1 grade + 1 contrib
    check_task_completion_csv unit, 19
  end

  def test_task_completion_csv_no_task_data
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:3, student_count:8, unenrolled_student_count: 1, part_enrolled_student_count: 2, set_one_of_each_task: true

    check_task_completion_csv unit
  end

  def test_task_completion_csv_all_td_in_one_stream
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:1, stream_count:1, task_count:1, student_count:3, unenrolled_student_count: 0, part_enrolled_student_count: 0

    unit.tutorial_streams << FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: unit.tutorial_streams.last, campus: unit.campuses.first )

    unit.projects.where(campus: tutorial.campus).first.enrol_in(tutorial)

    assert unit.task_definitions.first.tutorial_stream.present?
    assert_equal 2, unit.tutorial_streams.count

    check_task_completion_csv unit
  end

  def test_export_users
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:0, task_count:3, student_count:8, unenrolled_student_count: 0, part_enrolled_student_count: 0, set_one_of_each_task: true

    csv_str = unit.export_users_to_csv

    rows = 0
    CSV.parse(csv_str,
              headers: true, return_headers: false,
              header_converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')&.downcase }],
              converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') }]).each do |entry|
      assert_json_limit_keys_to_exactly %w[unit_code campus username student_id preferred_name first_name last_name email spec_con_days tutorial], entry.to_hash
      assert_equal 10, entry.count, entry
      user = User.find_by(username: entry['username'])
      assert user.present?, "Unable to find user from #{entry}"

      project = unit.projects.find_by(user_id: user.id)
      assert project.present?, entry

      assert_json_matches_model(user, entry, %w[username student_id first_name last_name email])

      campus = Campus.find_by('abbreviation = :name OR name = :name', name: entry['campus'])
      assert campus.present?, entry
      assert_equal project.campus, campus, entry

      if user.nickname.present?
        assert_equal user.nickname, entry['preferred_name'], entry
      else
        assert_nil entry['preferred_name'], entry
      end

      tutorial = unit.tutorials.find_by(abbreviation: entry['tutorial'])
      if entry['tutorial'].present?
        assert tutorial.present?, entry.inspect
        assert_equal project.tutorial_enrolments.first.tutorial, tutorial, entry
      else
        assert_nil tutorial
        assert_nil project.tutorial_enrolments.first
      end

      rows += 1
    end

    assert_equal unit.active_projects.count, rows, "Expected number or rows in csv - #{csv_str}"
  end

  test 'unit and task titles allow common teaching title punctuation' do
    assert FactoryBot.build(:unit, name: 'C# for Beginners (Part 1)').valid?
    assert FactoryBot.build(:task_definition, unit: @unit, name: 'Hyphenated-Task #1 (Core)').valid?
    assert FactoryBot.build(:task_definition, unit: @unit, name: 'P1.1 - Hello World').valid?
    assert FactoryBot.build(:task_definition, unit: @unit, name: "Student's Task").valid?
  end

  test 'unit and task titles reject equals, plus, and at characters anywhere' do
    ['={', '=2+2', '+command', '@command', 'Unit=Name', 'Unit+Name', 'Unit@Name'].each do |value|
      unit = FactoryBot.build(:unit, name: value)
      task_definition = FactoryBot.build(:task_definition, unit: @unit, name: value)

      assert_not unit.valid?, value
      assert_includes unit.errors[:name], 'contains unsupported characters'
      assert_not task_definition.valid?, value
      assert_includes task_definition.errors[:name], 'contains unsupported characters'
    end
  end

  test 'unit codes allow hyphens and slashes but reject unsupported characters' do
    assert FactoryBot.build(:unit, code: 'ABC1001-ABC1002').valid?
    assert FactoryBot.build(:unit, code: 'ABC1001-ABC1002C#').valid?
    assert FactoryBot.build(:unit, code: 'ABC1001/ABC1002').valid?

    ['ABC1001-ABC1002=', 'ABC1001+ABC1002', 'ABC1001@ABC1002'].each do |value|
      unit = FactoryBot.build(:unit, code: value)

      assert_not unit.valid?, value
      assert_includes unit.errors[:code], 'contains unsupported characters'
    end
  end

  test 'student export neutralises formulas from existing data' do
    unit = FactoryBot.create(:unit, student_count: 1, unenrolled_student_count: 0, part_enrolled_student_count: 0, inactive_student_count: 0)
    student = unit.active_projects.first.user
    student.assign_attributes(first_name: '=2+2', last_name: '+SUM(A1:A2)', nickname: '@command', student_id: '-1+2')
    student.save!(validate: false)

    entry = CSV.parse(unit.export_users_to_csv, headers: true).first

    assert_equal "'=2+2", entry['first_name']
    assert_equal "'+SUM(A1:A2)", entry['last_name']
    assert_equal "'@command", entry['preferred_name']
    assert_equal "'-1+2", entry['student_id']
  ensure
    unit&.destroy
  end

  def test_import_users
    unit = FactoryBot.create(:unit, code: 'SIT101', stream_count: 0, with_students: false, tutorials: 0)
    t1 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'B'),
      10,
      'LA1-01'
    )
    t2 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'C'),
      10,
      'LA1-03'
    )
    assert_equal 0, unit.projects.count

    assert_not_nil t1.campus
    assert_not_nil t2.campus

    result = unit.import_users_from_csv test_file_path('SIT101-Enrol-Students.csv')
    unit.reload
    # 1 Error due to invalid email + 2 Errors for failed tutorial/campus validation
    assert_equal 3, result[:errors].count, result.inspect
    assert_equal(2, result[:errors].count { |e| e[:message].include?("Enrolled student. UNABLE TO enroll in") }, "Expected two students to be created but failed tutorial enrolments")
    assert_equal 1, result[:ignored].count, result.inspect
    assert_equal 10, unit.projects.count, result.inspect

    assert_equal Campus.find_by(abbreviation: 'C'), User.find_by(username: 'import_8').projects.find_by(unit_id: unit.id).campus

    assert_equal 3, t1.projects.count, result.inspect
    assert_equal 3, t2.projects.count

    unit.destroy!
  end

  def test_import_users_streamed
    unit = FactoryBot.create(:unit, code: 'SIT101', stream_count: 0, with_students: false, tutorials: 0)
    s1 = unit.add_tutorial_stream('Stream 1', 'Prc01', ActivityType.first)
    s2 = unit.add_tutorial_stream('Stream 2', 'Stu01', ActivityType.first)

    t1 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'B'),
      10,
      'LA1-01',
      s1
    )
    t2 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'C'),
      10,
      'LA1-03',
      s1
    )
    t3 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      nil,
      10,
      'LA1-02',
      s2
    )

    assert_equal 0, unit.projects.count

    result = unit.import_users_from_csv test_file_path('SIT101-Enrol-Students-Stream.csv')
    unit.reload
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 0, result[:ignored].count, result.inspect
    assert_equal 8, unit.projects.count, result.inspect

    assert_equal 4, t1.projects.count
    assert_equal 4, t2.projects.count
    assert_equal 8, t3.projects.count

    unit.destroy!
  end

  def test_change_main_convenor_success
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = unit.employ_staff admin_user, Role.convenor
    convenor_user_role = unit.employ_staff convenor_user, Role.convenor

    unit.main_convenor_id = admin_user_role.id
    assert unit.valid?, 'It should be ok to change to the admin user'

    unit.main_convenor_id = convenor_user_role.id
    assert unit.valid?, 'It should be ok to change to the convenor user'
  end

  def test_change_main_convenor_does_not_allow_observer_only_roles
    unit = FactoryBot.create :unit, campus_count: 1, tutorials: 0, stream_count: 0, task_count: 0, with_students: false

    convenor_user = FactoryBot.create :user, :convenor
    convenor_user_role = unit.employ_staff convenor_user, Role.convenor
    convenor_user_role.update!(observer_only: true)

    unit.main_convenor_id = convenor_user_role.id
    assert_not unit.valid?, 'It should not be ok to change to an observer-only convenor user'

    convenor_user_role.update!(observer_only: false)
    unit.main_convenor.reload
    assert unit.valid?, 'It should be ok once the convenor user is no longer observer only'
  end

  def test_change_main_convenor_does_not_allow_roles_from_other_units
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false
    other_unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = other_unit.employ_staff admin_user, Role.convenor
    convenor_user_role = other_unit.employ_staff convenor_user, Role.convenor

    assert unit.valid?, 'Should be valid before changes... check factory girl!'

    unit.main_convenor_id = admin_user_role.id
    refute unit.valid?, 'It should not be ok to change to the admin user from other unit'

    unit.main_convenor_id = convenor_user_role.id
    refute unit.valid?, 'It should not be ok to change to the convenor user from other unit'
  end

  def test_change_main_convenor_does_not_allow_non_convneor_roles
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = unit.employ_staff admin_user, Role.tutor
    convenor_user_role = unit.employ_staff convenor_user, Role.tutor

    unit.main_convenor_id = admin_user_role.id
    refute unit.valid?, 'It should not be ok to change to the admin user with no convenor access to unit'

    unit.main_convenor_id = convenor_user_role.id
    refute unit.valid?, 'It should not be ok to change to the convenor user with no convenor access to unit'
  end

  def test_change_main_convenor_does_not_allow_students_to_be_epmployed
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    convenor_user = FactoryBot.create :user, :convenor
    student_user = FactoryBot.create :user, :student

    student_user_role = unit.employ_staff student_user, Role.tutor
    assert student_user_role.nil?

    #force this test... work around validations
    student_user_role = unit.employ_staff convenor_user, Role.convenor
    student_user_role.user = student_user

    refute student_user_role.valid?, 'You should not be able to change a unit role to have a student!'

    unit.main_convenor = student_user_role
    refute unit.valid?, 'Even if the above validation fails, the student user role should not be able to admin unit'
  end

  def test_portfolio_zip
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:1, student_count:1, unenrolled_student_count: 0, part_enrolled_student_count: 1

    paths = []

    unit.active_projects.each do |p|
      DatabasePopulator.generate_portfolio(p)
      assert p.portfolio_exists?
      assert File.exist?(p.portfolio_path)
      paths << p.portfolio_path
    end

    filename = unit.get_portfolio_zip(unit.main_convenor_user)
    assert File.exist? filename
    Zip::File.open(filename) do |zip_file|
      assert_equal unit.active_projects.count, zip_file.count
    end
    FileUtils.rm filename

    unit.destroy!

    paths.each do |path|
      refute File.exist?(path)
    end
  end

  def test_change_unit_code_moves_files
    unit = FactoryBot.create :unit, student_count: 1, unenrolled_student_count: 0, inactive_student_count: 0, task_count: 1, tutorials: 1, outcome_count: 0, staff_count: 0, campus_count: 1

    td = unit.task_definitions.first
    assert_not File.exist?(td.task_sheet)
    FileUtils.touch(td.task_sheet)
    assert File.exist?(td.task_sheet)

    old_path = td.task_sheet

    # also check tasks
    p = unit.projects.first
    task = p.task_for_task_definition(td)
    task_pdf = task.final_pdf_path
    FileUtils.touch(task_pdf)

    assert File.exist?(task_pdf)
    assert task_pdf.include?(unit.code)
    assert task_pdf.include?(unit.id.to_s)

    old_submission_history_path = FileHelper.unit_submission_history_dir(unit, archived: false)
    FileUtils.mkdir_p(old_submission_history_path)
    submission_history_file = 'output.txt'
    FileUtils.touch(File.join(old_submission_history_path, submission_history_file))
    assert File.exist?(File.join(old_submission_history_path, submission_history_file))

    old_jplag_report_path = FileHelper.task_jplag_report_path(unit, td)
    FileUtils.mkdir_p(File.dirname(old_jplag_report_path))
    FileUtils.touch(old_jplag_report_path)
    assert File.exist?(old_jplag_report_path)

    unit.code = "New-#{unit.code}"
    unit.save!

    td.reload
    task.reload

    assert_not_equal old_path, td.task_sheet
    assert_not File.exist?(old_path), "Old file still exists"
    assert File.exist?(td.task_sheet), "New file does not exist"

    assert_not_equal task.final_pdf_path, task_pdf
    assert_not File.exist?(task_pdf), "Old task file still exists"
    assert File.exist?(task.final_pdf_path), "New task file does not exist"

    assert File.exist?(task.final_pdf_path), "Portfolio evidence file does not exist = #{task.final_pdf_path}"
    assert task.has_pdf

    new_submission_history_path = FileHelper.unit_submission_history_dir(unit, archived: false)
    assert_not File.exist?(old_submission_history_path),
               "Old submission history still exists - #{old_submission_history_path}"
    assert File.exist?(File.join(new_submission_history_path, submission_history_file)),
           "New submission history file does not exist - #{new_submission_history_path}"

    assert_not File.exist?(old_jplag_report_path), "Old JPlag report still exists - #{old_jplag_report_path}"
    assert File.exist?(FileHelper.task_jplag_report_path(unit, td)), "New JPlag report does not exist"

    unit.destroy!
  end

  test 'rollover to set dates' do
    start_date = Time.zone.now
    end_date = start_date + 14.weeks

    unit2 = @unit.rollover(nil, start_date, end_date, nil)

    assert_equal @unit.code, unit2.code
    assert_in_delta start_date, unit2.start_date, 1.hour
    assert_in_delta end_date, unit2.end_date, 1.hour

    unit2.destroy
  end

  test 'rollover to new code with dates' do
    start_date = Time.zone.now
    end_date = start_date + 14.weeks

    unit2 = @unit.rollover(nil, start_date, end_date, 'NEWCODE-1')

    assert_not_equal @unit.code, unit2.code
    assert_equal 'NEWCODE-1', unit2.code
    assert_in_delta start_date, unit2.start_date, 1.hour
    assert_in_delta end_date, unit2.end_date, 1.hour

    unit2.destroy
  end

  test 'rollover to new code with teaching period' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files', "#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files', "#{@unit.code}-Tasks.zip")

    tp = TeachingPeriod.find(2)

    unit2 = @unit.rollover(tp, nil, nil, 'NEWCODE-1')

    assert_not_equal @unit.code, unit2.code
    assert_equal 'NEWCODE-1', unit2.code
    assert_equal tp, unit2.teaching_period

    unit2.task_definitions.each do |td|
      assert File.exist?(td.task_sheet), 'task sheet is absent'
    end

    assert File.exist?(unit2.task_definitions.first.task_resources), 'task resource is absent'

    # can rollover in the same teaching period with a new code
    unit3 = unit2.rollover(tp, nil, nil, 'NEWCODE-2')

    assert_not_equal unit2.code, unit3.code
    assert_equal 'NEWCODE-2', unit3.code
    assert_equal tp, unit3.teaching_period

    unit3.task_definitions.each do |td|
      assert File.exist?(td.task_sheet), 'task sheet is absent'
    end

    assert File.exist?(unit3.task_definitions.first.task_resources), 'task resource is absent'

    unit2.destroy
    unit3.destroy
  end

  def test_archive_unit
    Doubtfire::Application.config.archive_units = true
    unit = FactoryBot.create :unit, student_count: 1, unenrolled_student_count: 0, inactive_student_count: 0, task_count: 1, tutorials: 1, outcome_count: 0, staff_count: 0, campus_count: 1

    td = unit.task_definitions.first
    assert_not File.exist?(td.task_sheet)
    FileUtils.touch(td.task_sheet)
    assert File.exist?(td.task_sheet)

    old_path = td.task_sheet

    # also check tasks
    p = unit.projects.first
    task = p.task_for_task_definition(td)
    task_pdf = task.final_pdf_path
    FileUtils.touch(task_pdf)

    DatabasePopulator.generate_portfolio(p)
    old_portfolio_path = p.portfolio_path

    old_submission_history_path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, '123/45')
    FileUtils.mkdir_p(old_submission_history_path)
    FileUtils.touch(File.join(old_submission_history_path, 'output.txt'))

    old_jplag_report_path = FileHelper.task_jplag_report_path(unit, td)
    FileUtils.mkdir_p(File.dirname(old_jplag_report_path))
    FileUtils.touch(old_jplag_report_path)

    assert File.exist?(old_path)
    assert File.exist?(task_pdf)
    assert File.exist?(old_portfolio_path)
    assert File.exist?(old_submission_history_path)
    assert File.exist?(File.join(old_submission_history_path, 'output.txt'))
    assert File.exist?(old_jplag_report_path)

    unit.move_files_to_archive
    unit.archived = true
    unit.save!

    td.reload
    task.reload

    assert_not File.exist?(old_path), "Old file still exists"
    assert File.exist?(td.task_sheet), "New file does not exist - #{td.task_sheet}"
    assert_not File.exist?(task_pdf), "Old task file still exists"
    assert File.exist?(task.final_pdf_path), "New task file does not exist"
    assert_not File.exist?(old_portfolio_path), "Old portfolio file still exists - #{old_portfolio_path}"
    assert File.exist?(p.portfolio_path), "New portfolio file does not exist"
    assert_not File.exist?(old_submission_history_path), "Old submission history still exists - #{old_submission_history_path}"
    assert File.exist?(FileHelper.task_submission_identifier_path(:done, task))
    assert File.exist?(File.join(FileHelper.task_submission_identifier_path_with_timestamp(:done, task, '123_45'), 'output.txt'))
    assert_not File.exist?(old_jplag_report_path), "Old JPlag report still exists - #{old_jplag_report_path}"
    assert File.exist?(FileHelper.task_jplag_report_path(unit, td)), "New JPlag report does not exist"

    assert File.exist?(task.final_pdf_path), "Portfolio evidence file does not exist - #{task.final_pdf_path}"

    td.abbreviation = 'NEW'
    td.save
    task.reload

    # File exists after rename
    assert File.exist?(task.final_pdf_path), "Portfolio evidence file does not exist - #{task.final_pdf_path}"
    assert File.exist?(FileHelper.task_submission_identifier_path(:done, task))
    assert File.exist?(File.join(FileHelper.task_submission_identifier_path_with_timestamp(:done, task, '123_45'), 'output.txt'))

    p.student.update(username: 'NEW_USERNAME')
    task.reload
    assert File.exist?(task.final_pdf_path), "Portfolio evidence file does not exist after username change - #{task.final_pdf_path}"
    assert File.exist?(p.portfolio_path), "New portfolio file does not exist"
    assert File.exist?(FileHelper.task_submission_identifier_path(:done, task))
    assert File.exist?(File.join(FileHelper.task_submission_identifier_path_with_timestamp(:done, task, '123_45'), 'output.txt'))

    new_tp = FactoryBot.create :teaching_period
    new_unit = unit.rollover(new_tp, nil, nil, nil)

    assert_not new_unit.archived

    unit.destroy!

    assert_not File.exist?(td.task_sheet), "New file exists after delete - #{td.task_sheet}"
    assert_not File.exist?(task.final_pdf_path), "New task file exists after delete - #{task.final_pdf_path}"
    assert_not File.exist?(p.portfolio_path), "New portfolio exists after delete - #{p.portfolio_path}"
    assert_not File.exist?(FileHelper.task_submission_identifier_path(:done, task))
    assert_not File.exist?(File.join(FileHelper.task_submission_identifier_path_with_timestamp(:done, task, '123_45'), 'output.txt'))
  ensure
    Doubtfire::Application.config.archive_units = false
  end

  def test_archive_unit_job
    assert_not Doubtfire::Application.config.archive_units, 'Archive units should be off by default'

    unit = FactoryBot.create :unit, with_students: false, task_count: 0

    unit.end_date = Time.zone.now - Doubtfire::Application.config.unit_archive_after_period - 1.day
    unit.start_date = unit.end_date - 14.weeks
    unit.save!

    unit2 = FactoryBot.create :unit, with_students: false, task_count: 0

    assert_not unit.archived
    assert_not unit2.archived

    job = ArchiveOldUnitsJob.new
    job.perform

    unit.reload
    unit2.reload

    assert_not unit.archived
    assert_not unit2.archived

    Doubtfire::Application.config.archive_units = true

    job.perform
    unit.reload
    unit2.reload

    assert unit.archived
    assert_not unit2.archived
  end

  def test_overdue_tasks_update_to_assess_in_portfolio
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)
    unit.update(mark_late_submissions_as_assess_in_portfolio: false)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    student = unit.projects.first

    task1 = student.task_for_task_definition(td1)
    task2 = student.task_for_task_definition(td2)

    task1.comments.delete_all
    task2.comments.delete_all

    task1.update(task_status_id: TaskStatus.time_exceeded.id)

    task2.update(task_status_id: TaskStatus.feedback_exceeded.id)

    task1.reload
    task2.reload

    assert_equal TaskStatus.time_exceeded, task1.task_status
    assert_equal TaskStatus.feedback_exceeded, task2.task_status

    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

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

    lc = task2.last_comment
    assert_nil lc, "Task 2 should not have been moved to assess in portfolio state"
  end

  def test_cant_disable_aip_only_while_aip_tasks_exist
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td1 = unit.task_definitions.first

    student = unit.projects.first

    task1 = student.task_for_task_definition(td1)
    task1.update(task_status_id: TaskStatus.assess_in_portfolio.id)

    assert unit.valid?
    unit.mark_late_submissions_as_assess_in_portfolio = false

    assert_not unit.valid?, '"mark_late_submissions_as_assess_in_portfolio" cannot be disabled while tasks are in the Assess in Portfolio state'
    assert_includes unit.errors[:mark_late_submissions_as_assess_in_portfolio], 'cannot be disabled while tasks are in the Assess in Portfolio state'
  end


  test 'capture-task-complete-stats-snapshot creates snapshot for date' do
    data = build_unit_with_controlled_task_statuses
    unit = data[:unit]
    snapshot_time = Time.zone.local(2026, 4, 8, 23, 55, 0)
    expected_stats = parse_task_completion_stats_csv(unit, unit.task_completion_csv_generator(task_status_uses_id: true))

    count_before = unit.task_completion_snapshots.count
    snapshot = unit.capture_task_complete_stats_snapshot!(snapshot_time: snapshot_time)

    assert_equal count_before + 1, unit.task_completion_snapshots.count
    assert_equal snapshot_time.to_date, snapshot.snapshot_date
    assert_equal snapshot_time.to_i.to_s, snapshot.snapshot_timestamp
    assert_equal expected_stats, snapshot.load_stats

    persisted_snapshot = unit.task_completion_snapshots.find_by(snapshot_timestamp: snapshot_time.to_i.to_s)
    assert_not_nil persisted_snapshot
    assert_equal snapshot.id, persisted_snapshot.id
  ensure
    unit&.destroy
  end

  test 'capture-task-complete-stats-snapshot creates a new snapshot for a new timestamp' do
    data = build_unit_with_controlled_task_statuses
    unit = data[:unit]
    task_definitions = data[:task_definitions]
    student2 = data[:student2]

    first_time = Time.zone.local(2026, 4, 8, 9, 0, 0)
    second_time = Time.zone.local(2026, 4, 8, 20, 0, 0)

    first_snapshot = unit.capture_task_complete_stats_snapshot!(snapshot_time: first_time)
    first_stats = first_snapshot.load_stats.deep_dup
    count_before = unit.task_completion_snapshots.count

    # Change one task status so the new capture has different stats.
    student2.task_for_task_definition(task_definitions[0]).update!(task_status: TaskStatus.fail)
    expected_updated_stats = parse_task_completion_stats_csv(unit, unit.task_completion_csv_generator(task_status_uses_id: true))

    updated_snapshot = unit.capture_task_complete_stats_snapshot!(snapshot_time: second_time)

    assert_equal count_before + 1, unit.task_completion_snapshots.count
    assert_not_equal first_snapshot.id, updated_snapshot.id
    assert_equal second_time.to_i.to_s, updated_snapshot.snapshot_timestamp
    assert_not_equal first_stats, updated_snapshot.load_stats
    assert_equal expected_updated_stats, updated_snapshot.load_stats
  ensure
    unit&.destroy
  end

  private

  def parse_task_completion_stats_csv(unit, csv_text)
    csv = CSV.parse(csv_text, headers: true)
    streams = unit.tutorial_streams.pluck(:abbreviation)
    streams = ['Tutorial'] if streams.empty?
    task_definitions = unit.task_definitions_by_grade
    campus_header = csv.headers.find { |header| header.to_s.casecmp('Campus').zero? }

    campus_names_by_abbreviation = if campus_header.present?
                                     abbreviations = csv.map { |row| row[campus_header].to_s.strip }.reject(&:blank?).uniq
                                     Campus.where(abbreviation: abbreviations).pluck(:abbreviation, :name).to_h
                                   else
                                     {}
                                   end

    csv.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |row, stats|
      streams.each do |stream_name|
        tutorial_name = row[stream_name].to_s.strip
        next if tutorial_name.blank?

        campus_abbreviation = campus_header.present? ? row[campus_header].to_s.strip : nil

        campus_name = if campus_abbreviation.present?
                        campus_names_by_abbreviation[campus_abbreviation] || campus_abbreviation
                      elsif stream_name == 'Tutorial'
                        unit.tutorials.find_by(abbreviation: tutorial_name)&.campus&.name || stream_name
                      else
                        stream_name
                      end

        stats[campus_name][tutorial_name] ||= {}

        task_definitions.each do |task_definition|
          status_name = row[task_definition.abbreviation].to_s.strip
          status_key = TaskStatus.id_to_key(status_name.to_i) || :not_started
          stats[campus_name][tutorial_name][task_definition.abbreviation] ||= Hash.new(0)
          stats[campus_name][tutorial_name][task_definition.abbreviation][status_key.to_s] += 1
        end
      end
    end
  end

  def build_unit_with_controlled_task_statuses
    unit = FactoryBot.create(:unit, with_students: false, task_count: 2, stream_count: 0, tutorials: 1, campus_count: 1)
    tutorial = unit.tutorials.first
    campus = tutorial.campus
    task_definitions = unit.task_definitions.order(:id).to_a

    student1 = unit.enrol_student(FactoryBot.create(:user, :student), campus)
    student2 = unit.enrol_student(FactoryBot.create(:user, :student), campus)
    student1.enrol_in(tutorial)
    student2.enrol_in(tutorial)

    student1.task_for_task_definition(task_definitions[0]).update!(task_status: TaskStatus.complete)
    student2.task_for_task_definition(task_definitions[0]).update!(task_status: TaskStatus.complete)
    student1.task_for_task_definition(task_definitions[1]).update!(task_status: TaskStatus.fail)
    student2.task_for_task_definition(task_definitions[1]).update!(task_status: TaskStatus.not_started)

    {
      unit: unit,
      tutorial: tutorial,
      task_definitions: task_definitions,
      student1: student1,
      student2: student2
    }
  end

end
