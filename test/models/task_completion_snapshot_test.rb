require 'test_helper'

class TaskCompletionSnapshotTest < ActiveSupport::TestCase
  setup do
    @unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0, tutorials: 1, campus_count: 1)
    @snapshot = FactoryBot.create(:task_completion_snapshot, unit: @unit)
  end

  test 'task_completion_snapshot belongs to unit' do
    assert @snapshot.unit.is_a?(Unit)
    assert_equal @unit, @snapshot.unit
  end

  test 'task_completion_snapshot is valid with all attributes' do
    assert @snapshot.valid?
  end

  test 'task_completion_snapshot is invalid without snapshot_timestamp' do
    snapshot = FactoryBot.build(:task_completion_snapshot, snapshot_timestamp: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:snapshot_timestamp].include?("can't be blank")
  end

  test 'task_completion_snapshot enforces unique snapshot_timestamp per unit' do
    duplicate = FactoryBot.build(
      :task_completion_snapshot,
      unit: @unit,
      snapshot_timestamp: @snapshot.snapshot_timestamp
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:snapshot_timestamp].include?('has already been taken')
  end

  test 'task_completion_snapshot allows same snapshot_timestamp for different units' do
    other_unit = FactoryBot.create(:unit)
    snapshot = FactoryBot.build(
      :task_completion_snapshot,
      unit: other_unit,
      snapshot_timestamp: @snapshot.snapshot_timestamp
    )

    assert snapshot.valid?
  end

  test 'store_stats! writes a csv file contained in a zip that can be loaded' do
    tutorial = @unit.tutorials.first
    task_definition = @unit.task_definitions_by_grade.first

    payload = CSV.generate do |csv|
      csv << ['Student ID', 'Username', 'Student Name', 'Campus', 'Target Grade', 'Email', 'Portfolio', 'Grade', 'Rationale', 'Assessor', 'Tutorial', task_definition.abbreviation]
      csv << ['1', 'student-1', 'Student 1', tutorial.campus.abbreviation, @unit.grade_label(0), 'student-1@example.com', 'false', '', '', '', tutorial.abbreviation, TaskStatus.complete.id]
      csv << ['2', 'student-2', 'Student 2', tutorial.campus.abbreviation, @unit.grade_label(0), 'student-2@example.com', 'false', '', '', '', tutorial.abbreviation, TaskStatus.complete.id]
      csv << ['3', 'student-3', 'Student 3', tutorial.campus.abbreviation, @unit.grade_label(0), 'student-3@example.com', 'false', '', '', '', tutorial.abbreviation, TaskStatus.complete.id]
      csv << ['4', 'student-4', 'Student 4', tutorial.campus.abbreviation, @unit.grade_label(0), 'student-4@example.com', 'false', '', '', '', tutorial.abbreviation, TaskStatus.complete.id]
    end

    expected = {
      tutorial.campus.name => {
        tutorial.abbreviation => {
          task_definition.abbreviation => {
            'complete' => 4
          }
        }
      }
    }

    @snapshot.store_stats!(payload)

    assert File.exist?(@snapshot.snapshot_file_path)
    assert_equal expected, @snapshot.load_stats
    assert_equal 4, @snapshot.load_student_counts['student_count']
    assert_equal({ tutorial.campus.name => 4 }, @snapshot.load_student_counts['campus_student_counts'])
    assert_equal({ '0' => 4 }, @snapshot.load_student_counts['target_grade_student_counts'])
    assert_equal(
      { '0' => { tutorial.campus.name => 4 } },
      @snapshot.load_student_counts['target_grade_campus_student_counts']
    )
  end

  test 'load_stats returns empty hash if file missing' do
    snapshot = FactoryBot.create(
      :task_completion_snapshot,
      unit: @unit,
      snapshot_timestamp: (Time.zone.now.to_i + 100).to_s
    )

    FileUtils.rm_f(snapshot.snapshot_file_path)
    assert_equal({}, snapshot.load_stats)
  end

  test 'status population counts each student once across tutorial streams' do
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 2, tutorials: 1, campus_count: 1)
    snapshot = FactoryBot.create(:task_completion_snapshot, unit: unit)
    campus = unit.tutorials.first.campus
    task = unit.task_definitions_by_grade.first.abbreviation
    first_stream, second_stream = unit.tutorial_streams.pluck(:abbreviation)

    payload = CSV.generate do |csv|
      csv << ['Student ID', 'Username', 'Campus', 'Target Grade', first_stream, second_stream, task]
      csv << ['1', 'student-1', campus.abbreviation, unit.grade_label(0), 'T1', 'T2', TaskStatus.complete.id]
      csv << ['2', 'student-2', campus.abbreviation, unit.grade_label(0), 'T1', '', TaskStatus.not_started.id]
      csv << ['1', 'student-1', campus.abbreviation, unit.grade_label(0), 'T1', 'T2', TaskStatus.complete.id]
    end
    snapshot.store_stats!(payload)

    population = snapshot.load_status_population_stats
    all_tutorials = population['all'][campus.name]

    assert_equal({ 'complete' => 1, 'not_started' => 1 }, all_tutorials['__all__'][task])
    assert_equal({ 'complete' => 1, 'not_started' => 1 }, all_tutorials['T1'][task])
    assert_equal({ 'complete' => 1 }, all_tutorials['T2'][task])
    assert_equal all_tutorials, population['target_grades']['0'][campus.name]
  end

  test 'deleting snapshot deletes associated zip file' do
    tutorial = @unit.tutorials.first
    task_definition = @unit.task_definitions_by_grade.first

    payload = CSV.generate do |csv|
      csv << ['Student ID', 'Username', 'Student Name', 'Target Grade', 'Email', 'Portfolio', 'Grade', 'Rationale', 'Assessor', 'Tutorial', task_definition.abbreviation]
      csv << ['1', 'student-1', 'Student 1', @unit.grade_label(0), 'student-1@example.com', 'false', '', '', '', tutorial.abbreviation, TaskStatus.complete.id]
    end

    @snapshot.store_stats!(payload)

    file_path = @snapshot.snapshot_file_path
    assert File.exist?(file_path)

    @snapshot.destroy
    assert_not File.exist?(file_path)
  end

  test 'snapshot_date is derived from snapshot_timestamp' do
    timestamp = Time.zone.local(2026, 4, 8, 23, 55, 0).to_i.to_s
    snapshot = FactoryBot.build(:task_completion_snapshot, snapshot_timestamp: timestamp)

    assert_equal Date.new(2026, 4, 8), snapshot.snapshot_date
  end
end
