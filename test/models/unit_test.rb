require 'test_helper'

class UnitTest < ActiveSupport::TestCase
  
  def setup
    data = {
        code: 'COS10001',
        name: 'Testing in Unit Tests',
        description: faker_random_sentence(10, 15),
        teaching_period_id: TeachingPeriod.find(3).id
      }
    @unit = Unit.create(data)
  end

  test 'import tasks worked' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    assert_equal 36, @unit.task_definitions.count, 'imported all task definitions'
  end

  test 'import task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    assert File.exists? @unit.task_definitions.first.task_sheet
    assert File.exists? @unit.task_definitions.first.task_resources
  end

  test 'rollover of task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    assert File.exists?(unit2.task_definitions.first.task_sheet), 'task sheet is absent'
    assert File.exists?(unit2.task_definitions.first.task_resources), 'task resource is absent'
  end

  test 'rollover of tasks' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.start_day, td2.start_day, "#{td.abbreviation} not on same day"
      assert_equal td.start_week, td2.start_week, "#{td.abbreviation} not in same week"
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
        
        case rand(1..100)
        when 1..20 
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.complete, td.due_date + 1.week)  
        when 21..40
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.ready_to_mark, td.due_date + 1.week)  
        when 41..50
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.time_exceeded, td.due_date + 1.week)
        when 51..60
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.not_started, td.due_date + 1.week)
        when 61..70
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.working_on_it, td.due_date + 1.week)
        when 71..80
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.discuss, td.due_date + 1.week)
        else
          DatabasePopulator.assess_task(student, task, student.main_tutor, TaskStatus.fix_and_resubmit, td.due_date + 1.week)
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
end
