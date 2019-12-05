require 'test_helper'

class UnitTest < ActiveSupport::TestCase
  
  setup do
    data = {
        code: 'COS10001',
        name: 'Testing in Unit Tests',
        description: 'Test unit',
        teaching_period: TeachingPeriod.find(3)
      }
    @unit = Unit.create(data)

    activity_type = FactoryGirl.create(:activity_type)
    @unit.add_tutorial_stream('Import-Tasks', 'import-tasks', activity_type)
  end

  teardown do
    @unit.destroy
  end

  test 'import tasks worked' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    assert_equal 36, @unit.task_definitions.count, 'imported all task definitions'
  end

  test 'import task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    @unit.task_definitions.each do |td|
      assert File.exists?(td.task_sheet), "#{td.abbreviation} task sheet missing"
    end

    assert File.exists? @unit.task_definitions.first.task_resources
  end

  test 'rollover of task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    unit2.task_definitions.each do |td|
      assert File.exists?(td.task_sheet), 'task sheet is absent'
    end

    assert File.exists?(unit2.task_definitions.first.task_resources), 'task resource is absent'

    unit2.destroy
  end

  test 'rollover of group tasks' do
    unit = FactoryGirl.create(:unit,
      code: 'SIT102',
      teaching_period: TeachingPeriod.find(3),
      group_sets: 1,
      student_count: 2,
      groups: [ { gs: 0, students: 2} ],
      group_tasks: [ { idx: 0, gs: 0 }] )

    unit2 = unit.rollover TeachingPeriod.find(2), nil, nil

    assert_equal 1, unit2.group_sets.count
    assert_not_equal unit2.group_sets.first, unit.group_sets.first
    assert unit2.task_definitions.first.is_group_task?

    unit.destroy
    unit2.destroy
  end

  test 'rollover of task ilo links' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    @unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Alignment.csv")), nil

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    assert @unit.task_outcome_alignments.count > 0
    assert_equal @unit.task_outcome_alignments.count, unit2.task_outcome_alignments.count

    @unit.task_outcome_alignments.each do |link|
      ilo = unit2.learning_outcomes.find_by(abbreviation: link.learning_outcome.abbreviation)
      task_def = unit2.task_definitions.find_by(abbreviation: link.task_definition.abbreviation)
      other = unit2.task_outcome_alignments.where(task_definition_id: task_def.id, learning_outcome_id: ilo.id).first

      assert other
      assert_equal link.rating, other.rating, "rating does not match for #{link.task_definition.abbreviation} - #{link.learning_outcome.abbreviation}"
    end
  end

  test 'rollover of tasks have same start week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    assert_equal 3, @unit.teaching_period_id
    assert_equal 2, unit2.teaching_period_id

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)

      assert_equal td.start_day, td2.start_day, "#{td.abbreviation} not on same day"
      assert_equal td.start_week, td2.start_week, "#{td.abbreviation} not in same week"
    end
  end

  test 'rollover of tasks have same target week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.target_day, td2.target_day, "#{td.abbreviation} not on same day"
      assert_equal td.target_week, td2.target_week, "#{td.abbreviation} not targetting same week"
    end
  end

  test 'rollover of tasks have same due week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.due_day, td2.due_day, "#{td.abbreviation} not on same day"
      assert_equal td.due_week, td2.due_week, "#{td.abbreviation} not due same week"
    end
  end


  test 'ensure valid response from unit ilo data' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    @unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Alignment.csv")), nil

    DatabasePopulator.new.generate_tutorials_and_enrol_students_for_unit @unit, {
      tutors: [
        { user: :acain, num: 1 },
        { user: :aconvenor, num: 2 },
      ],
      students: [ ]
    }

    assert_equal 3, @unit.tutorials.count

    @unit.students.each do |student|
      @unit.task_definitions.each do |td|
        task = student.task_for_task_definition(td)
        tutor = student.tutor_for(td)

        case rand(1..100)
        when 1..20
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.complete, td.due_date + 1.week)
        when 21..40
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.ready_to_mark, td.due_date + 1.week)
        when 41..50
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.time_exceeded, td.due_date + 1.week)
        when 51..60
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.not_started, td.due_date + 1.week)
        when 61..70
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.working_on_it, td.due_date + 1.week)
        when 71..80
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.discuss, td.due_date + 1.week)
        else
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.fix_and_resubmit, td.due_date + 1.week)
        end

        break if rand(1..100) > 80
      end
    end

    details = @unit.ilo_progress_class_details

    assert details.key?('all'), 'contains all key'

    @unit.tutorials.each do |tute|
      assert details.key?(tute.id), 'contains tutorial keys'
    end
  end

  def test_student_query
    unit = FactoryGirl.create(:unit)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryGirl.create(:campus)

    assert_empty unit.projects
    project = FactoryGirl.create(:project, unit: unit, campus: campus)
    assert_equal 1, unit.projects.count


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

    projects = unit.student_query(false)

    assert_equal unit.projects.count, projects.count
    assert_equal 1, projects.count

    # Check returned project
    assert_equal project.id, projects.first[:project_id]
    assert_equal project.enrolled, projects.first[:enrolled]

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.first[:tutorial_streams].count

    # Now test with project without tutorial enrolments
    project2 = FactoryGirl.create(:project, unit: unit, campus: campus)
    assert_equal 2, unit.projects.count

    project2.tutorial_enrolments.destroy

    projects = unit.student_query(false)

    assert_equal unit.projects.count, projects.count
    assert_equal 2, projects.count

    # Check returned project
    assert projects.select{|p| p[:project_id] == project2.id}.first.present?

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.last[:tutorial_streams].count

    unit.tutorial_streams.each do |s|
      unit.projects.each do |p|
        proj_tute_enrolment = p.tutorial_enrolments.where(tutorial_stream_id: s.id).first
        data_tute_enrolment = projects.select{|ps| ps[:project_id] == p.id}.first[:tutorial_streams].select{|te| te[:stream] == s.abbreviation}.map{|te| te[:tutorial]}.first

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

  def test_task_completion_csv
    unit = FactoryGirl.create :unit, campus_count: 2, tutorials:2, stream_count:2, student_count:10

  end
end
