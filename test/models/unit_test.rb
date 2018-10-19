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

    # @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    # @unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Alignment.csv")), nil
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

  test 'ensure valid response from unit ilo data' do
    @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    DatabasePopulator.new.generate_tutorials_and_enrol_students_for_unit @unit, {
      tutors: [
        { user: :acain, num: 2 },
        { user: :aconvenor, num: 2 },
      ],
      students: [ ]
    }
    details = @unit.ilo_progress_class_details

    assert details.key?('all'), 'contains all key'

    @unit.tutorials.each do |tute|
      assert details.key?(tute.id), 'contains tutorial keys'
    end
  end
end
