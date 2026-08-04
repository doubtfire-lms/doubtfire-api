# frozen_string_literal: true

class ImportMoodleStudentsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, preview_only)
    at(0, 'Fetching enrolled Moodle students')
    total(0)

    unit = Unit.find(unit_id)
    raise MoodleApi::Error, 'Moodle integration is not enabled for this unit' unless unit.moodle_enabled?

    integration = unit.moodle_integration
    raise MoodleApi::Error, 'Configure Moodle for this unit first' if integration.blank?

    students = MoodleApi.new(integration).students.select do |student|
      Array(student['roles']).any? { |role| role['shortname'] == 'student' }
    end
    total(students.length)

    rows = students.map do |student|
      display_row = {
        unit_code: unit.code,
        username: student['username'],
        student_id: student['idnumber'],
        first_name: student['firstname'],
        last_name: student['lastname'],
        nickname: student['firstname'],
        email: student['email'],
        enrolled: true
      }
      display_row.merge(row: display_row, tutorials: [], campus: nil)
    end

    result = if preview_only
               {
                 success: rows.map.with_index(1) do |row, index|
                   at(index, "Reading Moodle student #{row[:username]}")
                   { row: row[:row], message: 'Student data fetched from Moodle' }
                 end,
                 ignored: [],
                 errors: []
               }
             else
               import_students(unit, rows)
             end

    store(result: result.to_json)
  end

  private

  def import_students(unit, rows)
    result = { success: [], ignored: [], errors: [] }
    unit.sync_enrolment_with(
      rows,
      {
        replace_existing_tutorial: false,
        replace_existing_campus: false,
        merge_duplicate_students: false
      },
      result,
      progress_callback: lambda { |message: nil, total_rows: nil, rows_processed: nil|
        total(total_rows) if total_rows
        at(rows_processed, message) if rows_processed
      }
    )
    result
  end
end
