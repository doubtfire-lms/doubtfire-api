# frozen_string_literal: true

class ImportMoodleExtensionsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, preview_only)
    total(3)
    at(0, 'Fetching Moodle assignment')

    unit = Unit.find(unit_id)
    raise MoodleApi::Error, 'Moodle integration is not enabled for this unit' unless unit.moodle_enabled?

    integration = unit.moodle_integration
    raise MoodleApi::Error, 'Configure Moodle for this unit first' if integration.blank?
    unless integration.fetch_extensions && integration.assignment_id.present?
      raise MoodleApi::Error, 'Enable extension imports and select a Moodle assignment first'
    end

    moodle = MoodleApi.new(integration)
    assignment_response = moodle.assignments
    assignments = MoodleIntegrationValidator.assignments_for_course(integration, assignment_response)
    at(0, 'Validating Moodle integration')
    MoodleIntegrationValidator.new(integration).validate!(
      groups: moodle.course_groups,
      assignments: assignments
    )
    assignment = assignments.find do |item|
      item['id'].to_i == integration.assignment_id
    end
    raise MoodleApi::Error, 'The selected assignment was not found in this course' if assignment.blank?

    at(1, 'Fetching enrolled Moodle students')
    students = moodle.students.index_by { |student| student['id'].to_i }

    at(2, 'Fetching Moodle extensions')
    flags = moodle.user_flags
    assignment_flags = Array(flags['assignments']).find do |item|
      item['assignmentid'].to_i == integration.assignment_id
    end
    user_flags = Array(assignment_flags&.fetch('userflags', nil)).select do |flag|
      flag['extensionduedate'].to_i.positive?
    end
    total(3 + user_flags.length)

    result = { success: [], ignored: [], errors: [] }
    user_flags.each_with_index do |flag, index|
      student = students[flag['userid'].to_i]
      extension_date = Time.zone.at(flag['extensionduedate'].to_i).to_date
      row = {
        username: student&.fetch('username', nil),
        extension_date: extension_date.iso8601,
        spec_con_days: nil
      }

      begin
        days = [
          (extension_date - Time.zone.at(assignment['duedate'].to_i).to_date).to_i,
          0
        ].max
        row[:spec_con_days] = days

        project = unit.projects.joins(:user).find_by(users: { username: row[:username] })
        if project.blank?
          result[:ignored] << { row: row, message: 'Student is not enrolled in OnTrack' }
          next
        end

        if project.spec_con_days == days
          result[:ignored] << { row: row, message: 'Special consideration days are unchanged' }
        else
          project.update!(spec_con_days: days) unless preview_only
          message = preview_only ? "Would update special consideration to #{days} days" : "Special consideration updated to #{days} days"
          result[:success] << { row: row, message: message }
        end
      rescue StandardError => e
        result[:errors] << { row: row, message: e.message }
      ensure
        at(3 + index + 1, "Processing extension for #{row[:username] || 'unknown student'}")
      end
    end

    store(result: result.to_json)
  end
end
