require 'test_helper'

class TutorialCsvTest < ActiveSupport::TestCase
  def test_tutorials_csv_lists_one_row_per_tutorial
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    campus = FactoryBot.create(:campus)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, campus, 20, 'T1', stream)

    rows = CSV.parse(unit.tutorials_csv)

    assert_equal %w[abbreviation tutorial_stream meeting_day meeting_time meeting_location duration_minutes capacity tutor_username campus], rows[0]
    assert_equal ['T1', 'lab-1', 'Monday', '10:00', 'ATC101', '120', '20', tutor.username, campus.abbreviation], rows[1]
  end

  def test_tutorials_csv_import_creates_tutorial_with_defaults
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))

    csv_file = Tempfile.new(['tutorials-create-defaults', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T9', 'lab-1', 'Tuesday', '11:00', 'ATC102', nil, nil, nil, nil]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal "Created tutorial T9. Tutor set to the main convenor #{unit.main_convenor_user.username}.", result[:success].first[:message]
    tutorial = unit.tutorials.find_by(abbreviation: 'T9')
    assert_equal stream, tutorial.tutorial_stream
    assert_equal unit.main_convenor_user, tutorial.tutor
    assert_equal 120, tutorial.duration_minutes
    assert_equal(-1, tutorial.capacity)
    assert_nil tutorial.campus
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_creates_tutorial_with_all_values
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Workshop', 'wrk-1', FactoryBot.create(:activity_type))
    campus = FactoryBot.create(:campus)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    csv_file = Tempfile.new(['tutorials-create-all', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T9', 'wrk-1', 'Friday', '09:00', 'ATC103', '90', '25', tutor.username, campus.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 'Created tutorial T9.', result[:success].first[:message]
    tutorial = unit.tutorials.find_by(abbreviation: 'T9')
    assert_equal stream, tutorial.tutorial_stream
    assert_equal 'Friday', tutorial.meeting_day
    assert_equal '09:00', tutorial.meeting_time
    assert_equal 'ATC103', tutorial.meeting_location
    assert_equal 90, tutorial.duration_minutes
    assert_equal 25, tutorial.capacity
    assert_equal tutor, tutorial.tutor
    assert_equal campus, tutorial.campus
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_reads_numbers_as_decimal
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))

    csv_file = Tempfile.new(['tutorials-decimal', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T9', 'lab-1', 'Tuesday', '11:00', 'ATC102', '08', nil, nil, nil]
    end)
    csv_file.rewind

    unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 8, unit.tutorials.find_by(abbreviation: 'T9').duration_minutes
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_updates_tutorial
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    activity_type = FactoryBot.create(:activity_type)
    lab = unit.add_tutorial_stream('Lab', 'lab-1', activity_type)
    workshop = unit.add_tutorial_stream('Workshop', 'wrk-1', activity_type)
    campus = FactoryBot.create(:campus)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, campus, 20, 'T1', lab)

    csv_file = Tempfile.new(['tutorials-update', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T1', 'wrk-1', 'Friday', '09:00', "'=Room 1", '90', '25', unit.main_convenor_user.username, campus.name]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 'Updated tutorial T1.', result[:success].first[:message]
    tutorial = unit.tutorials.find_by(abbreviation: 'T1')
    assert_equal workshop, tutorial.tutorial_stream
    assert_equal 'Friday', tutorial.meeting_day
    assert_equal '09:00', tutorial.meeting_time
    assert_equal '=Room 1', tutorial.meeting_location
    assert_equal 90, tutorial.duration_minutes
    assert_equal 25, tutorial.capacity
    assert_equal unit.main_convenor_user, tutorial.tutor
    assert_equal campus, tutorial.campus
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_same_tutor_is_ignored
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    campus = FactoryBot.create(:campus)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, campus, 20, 'T1', stream)

    csv_file = Tempfile.new(['tutorials-same-tutor', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T1', 'lab-1', 'Monday', '10:00', 'ATC101', '120', '20', tutor.username, campus.abbreviation]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 0, result[:success].size
    assert_equal 'No changes to tutorial T1.', result[:ignored].first[:message]
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_blank_cells_keep_values
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    campus = FactoryBot.create(:campus)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, campus, 20, 'T1', stream)

    csv_file = Tempfile.new(['tutorials-blank', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T1', nil, nil, nil, nil, nil, nil, nil, nil]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 'No changes to tutorial T1.', result[:ignored].first[:message]
    tutorial = unit.tutorials.find_by(abbreviation: 'T1')
    assert_equal stream, tutorial.tutorial_stream
    assert_equal 'Monday', tutorial.meeting_day
    assert_equal tutor, tutorial.tutor
    assert_equal campus, tutorial.campus
    assert_equal 20, tutorial.capacity
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_round_trip_is_ignored
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    activity_type = FactoryBot.create(:activity_type)
    lab = unit.add_tutorial_stream('Lab', 'lab-1', activity_type)
    workshop = unit.add_tutorial_stream('Workshop', 'wrk-1', activity_type)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, FactoryBot.create(:campus), 20, 'T1', lab)
    unit.add_tutorial('Wednesday', '14:00', '=Lab', unit.main_convenor_user, nil, -1, 'T2', workshop)

    csv_file = Tempfile.new(['tutorials-round-trip', '.csv'])
    csv_file.write(unit.tutorials_csv)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 0, result[:success].size
    assert_equal 2, result[:ignored].size
    assert_equal 0, result[:errors].size
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_reports_row_errors
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    student = FactoryBot.create(:user, :student)

    csv_file = Tempfile.new(['tutorials-errors', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['N1', nil, 'Monday', '10:00', 'X', nil, nil, nil, nil]
      csv << ['N2', 'lab-1', nil, nil, nil, nil, nil, nil, nil]
      csv << [nil, 'lab-1', 'Monday', '10:00', 'X', nil, nil, nil, nil]
      csv << ['N3', 'nope-1', 'Monday', '10:00', 'X', nil, nil, nil, nil]
      csv << ['N4', 'lab-1', 'Monday', '10:00', 'X', nil, nil, student.username, nil]
      csv << ['N5', 'lab-1', 'Monday', '10:00', 'X', nil, nil, nil, 'not-a-campus']
      csv << ['N6', 'lab-1', 'Monday', '10:00', 'X', '0', nil, nil, nil]
      csv << ['N7', 'lab-1', 'Monday', '10:00', 'X', nil, 'abc', nil, nil]
      csv << ['OK', 'lab-1', 'Monday', '10:00', 'X', nil, nil, nil, nil]
      csv << ['OK', 'lab-1', 'Monday', '10:00', 'X', nil, nil, nil, nil]
    end)
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 1, result[:success].size
    assert_equal [
      'tutorial_stream required to create tutorial N1.',
      'meeting_day, meeting_time, meeting_location required to create tutorial N2.',
      'Abbreviation cannot be empty.',
      "Tutorial stream 'nope-1' not found -- import it with the tutorial streams CSV first.",
      "#{student.username} is not a tutor or convenor in this unit.",
      "Campus 'not-a-campus' not found.",
      "duration_minutes must be a whole number of 1 or more (got '0').",
      "capacity must be a whole number of -1 or more (got 'abc').",
      'Tutorial OK appears more than once in the file.'
    ], result[:errors].map { |error| error[:message] }
    assert_equal ['OK'], unit.tutorials.reload.pluck(:abbreviation)
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_needs_main_convenor_for_blank_tutor
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    unit.update_column(:main_convenor_id, nil)

    csv_file = Tempfile.new(['tutorials-no-convenor', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T9', 'lab-1', 'Tuesday', '11:00', 'ATC102', nil, nil, nil, nil]
    end)
    csv_file.rewind

    result = unit.reload.import_tutorials_from_csv(csv_file.path)

    assert_equal 'No tutor given for T9 and the unit has no main convenor.', result[:errors].first[:message]
    assert_equal 0, unit.tutorials.count
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutorials_csv_import_rejects_missing_headers
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all

    csv_file = Tempfile.new(['tutorials-headers', '.csv'])
    csv_file.write("abbreviation,tutorial_stream,meeting_day\nT9,lab-1,Monday\n")
    csv_file.rewind

    result = unit.import_tutorials_from_csv(csv_file.path)

    assert_equal 0, result[:success].size
    assert_equal 'Missing headers: meeting_time, meeting_location, duration_minutes, capacity, tutor_username, campus', result[:errors].first[:message]
    assert_equal 0, unit.tutorials.count
  ensure
    csv_file&.close
    csv_file&.unlink
  end
end
