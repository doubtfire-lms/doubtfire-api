require 'test_helper'

class TutorialStreamCsvTest < ActiveSupport::TestCase
  def test_tutorial_streams_csv_lists_streams_by_abbreviation
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    workshop_type = FactoryBot.create(:activity_type)
    class_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Workshop', 'wrk-1', workshop_type)
    unit.add_tutorial_stream('Class', 'cls-1', class_type)

    rows = CSV.parse(unit.tutorial_streams_csv)

    assert_equal %w[abbreviation name activity_type], rows[0]
    assert_equal ['cls-1', 'Class', class_type.abbreviation], rows[1]
    assert_equal ['wrk-1', 'Workshop', workshop_type.abbreviation], rows[2]
  end

  def test_tutorial_streams_csv_escapes_formula_values
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('=Formula', 'f-1', activity_type)

    rows = CSV.parse(unit.tutorial_streams_csv)

    assert_equal ['f-1', "'=Formula", activity_type.abbreviation], rows[1]
  end

  def test_tutorial_streams_csv_import_creates_stream
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)

    csv_file = Tempfile.new(['tutorial-streams-create', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['lab-1', 'Lab-1', activity_type.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 1, result[:success].size
    assert_equal 0, result[:errors].size
    assert_equal 'Created stream lab-1.', result[:success].first[:message]
    stream = unit.tutorial_streams.find_by(abbreviation: 'lab-1')
    assert_equal 'Lab-1', stream.name
    assert_equal activity_type, stream.activity_type
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_matches_activity_type_by_name
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)

    csv_file = Tempfile.new(['tutorial-streams-type-name', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['lab-1', 'Lab-1', activity_type.name]
    end)
    csv_file.rewind

    unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal activity_type, unit.tutorial_streams.find_by(abbreviation: 'lab-1').activity_type
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_updates_stream_by_abbreviation
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    old_type = FactoryBot.create(:activity_type)
    new_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Lab-1', 'lab-1', old_type)

    csv_file = Tempfile.new(['tutorial-streams-update', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['lab-1', 'Lab One', new_type.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 1, result[:success].size
    assert_equal 'Updated stream lab-1.', result[:success].first[:message]
    stream = unit.tutorial_streams.find_by(abbreviation: 'lab-1')
    assert_equal 'Lab One', stream.name
    assert_equal new_type, stream.activity_type
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_blank_cells_keep_values
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Lab-1', 'lab-1', activity_type)

    csv_file = Tempfile.new(['tutorial-streams-blank', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['lab-1', nil, nil]
    end)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 1, result[:ignored].size
    assert_equal 'No changes to stream lab-1.', result[:ignored].first[:message]
    stream = unit.tutorial_streams.find_by(abbreviation: 'lab-1')
    assert_equal 'Lab-1', stream.name
    assert_equal activity_type, stream.activity_type
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_round_trip_is_ignored
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Lab-1', 'lab-1', activity_type)
    unit.add_tutorial_stream('=Formula', 'f-1', activity_type)

    csv_file = Tempfile.new(['tutorial-streams-round-trip', '.csv'])
    csv_file.write(unit.tutorial_streams_csv)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 0, result[:success].size
    assert_equal 2, result[:ignored].size
    assert_equal 0, result[:errors].size
    assert_equal '=Formula', unit.tutorial_streams.find_by(abbreviation: 'f-1').name
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_reports_row_errors
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Taken', 'taken-1', activity_type)

    csv_file = Tempfile.new(['tutorial-streams-errors', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['new-1', nil, activity_type.abbreviation]
      csv << [nil, 'Nameless', activity_type.abbreviation]
      csv << ['bad-1', 'Bad', 'not-a-type']
      csv << ['dup-name', 'Taken', activity_type.abbreviation]
      csv << ['ok-1', 'Ok', activity_type.abbreviation]
      csv << ['ok-1', 'Again', activity_type.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 1, result[:success].size
    assert_equal 'Created stream ok-1.', result[:success].first[:message]
    assert_equal [
      'Name and activity type are required to create stream new-1.',
      'Abbreviation cannot be empty.',
      "Unknown activity type 'not-a-type' -- use one of: #{ActivityType.pluck(:abbreviation).sort.join(', ')}",
      'Name Taken already exists in this unit',
      'Stream ok-1 appears more than once in the file.'
    ], result[:errors].map { |error| error[:message] }
    assert_nil unit.tutorial_streams.find_by(abbreviation: 'new-1')
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_rejects_missing_headers
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    csv_file = Tempfile.new(['tutorial-streams-headers', '.csv'])
    csv_file.write("abbreviation,name\nlab-1,Lab-1\n")
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal 0, result[:success].size
    assert_equal 'Missing headers: activity_type', result[:errors].first[:message]
    assert_equal 0, unit.tutorial_streams.count
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorial_streams_csv_import_first_stream_takes_all_tasks
    unit = FactoryBot.create(:unit, with_students: false, task_count: 3)
    activity_type = FactoryBot.create(:activity_type)
    task_count = unit.task_definitions.count

    csv_file = Tempfile.new(['tutorial-streams-first', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['lab-1', 'Lab-1', activity_type.abbreviation]
      csv << ['lab-2', 'Lab-2', activity_type.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorial_streams_from_csv(csv_file.path)

    assert_equal [
      "Created stream lab-1. All #{task_count} tasks were assigned to it as it is the first stream in the unit.",
      'Created stream lab-2.'
    ], result[:success].map { |success| success[:message] }
    assert_equal task_count, unit.tutorial_streams.find_by(abbreviation: 'lab-1').task_definitions.count
  ensure
    csv_file&.close
    csv_file&.unlink
  end
end
