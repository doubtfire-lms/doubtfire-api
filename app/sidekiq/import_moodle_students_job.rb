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

    moodle = MoodleApi.new(integration)
    students = moodle.students.select do |student|
      Array(student['roles']).any? { |role| role['shortname'] == 'student' }
    end
    mappings = integration.group_mapping_enabled? ? integration.moodle_group_mappings.includes(:group_set, :group, :campus, :tutorial_stream, :tutorial) : []
    mappings_by_group_id = mappings.index_by(&:moodle_group_id)
    total(students.length)

    rows = students.map do |student|
      student_mappings = Array(student['groups']).filter_map do |group|
        mappings_by_group_id[group['id'].to_i]
      end
      display_row = {
        unit_code: unit.code,
        username: student['username'],
        student_id: student['idnumber'],
        first_name: student['firstname'],
        last_name: student['lastname'],
        nickname: student['firstname'],
        email: student['email'],
        moodle_groups: student_mappings.map(&:moodle_group_name).join(', '),
        mapped_campus: student_mappings.filter_map { |mapping| mapping.campus&.name }.uniq.join(', '),
        mapped_tutorial: student_mappings.select { |mapping| mapping.target_type == 'tutorial' }.map { |mapping| mapping.tutorial&.abbreviation || mapping.moodle_group_name }.uniq.join(', '),
        mapped_group: student_mappings.select { |mapping| mapping.target_type == 'group' }.map { |mapping| mapping.group&.name || mapping.moodle_group_name }.uniq.join(', '),
        enrolled: true
      }
      display_row.merge(row: display_row, tutorials: [], campus: nil, moodle_mappings: student_mappings)
    end

    result = if preview_only
               preview_students(rows)
             else
               import_students(unit, rows)
             end

    store(result: result.to_json)
  end

  private

  def preview_students(rows)
    result = { success: [], ignored: [], errors: [] }
    rows.each_with_index do |row, index|
      at(index + 1, "Reading Moodle student #{row[:username]}")
      errors = mapping_errors(row[:moodle_mappings])
      result[errors.empty? ? :success : :errors] << {
        row: row[:row],
        message: errors.empty? ? 'Student data and group mappings fetched from Moodle' : errors.join('; ')
      }
    end
    result
  end

  def import_students(unit, rows)
    result = { success: [], ignored: [], errors: [] }
    unit.sync_enrolment_with(
      rows.map { |row| row.except(:moodle_mappings) },
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

    rows.each do |row|
      next if row[:moodle_mappings].empty?

      project = unit.projects.joins(:user).find_by(users: { username: row[:username] })
      errors = mapping_errors(row[:moodle_mappings])
      errors << 'Student could not be found after import' unless project
      mappings_changed = false
      if errors.empty?
        begin
          mappings_changed = apply_mappings(project, row[:moodle_mappings])
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
          errors << "Group mapping failed: #{e.message}"
        end
      end

      existing_entry = nil
      existing_type = nil
      [:success, :ignored].each do |type|
        entry = result[type].find { |item| item[:row][:username] == row[:username] }
        next unless entry

        existing_entry = entry
        existing_type = type
        result[type].delete(entry) if errors.present? || (mappings_changed && type == :ignored)
      end

      if errors.present?
        result[:errors] << { row: row[:row], message: errors.join('; ') }
      elsif mappings_changed && existing_entry
        existing_entry[:message] = "#{existing_entry[:message].to_s.delete_suffix('.')}; Moodle group mappings updated"
        result[:success] << existing_entry unless result[:success].include?(existing_entry)
      elsif mappings_changed
        result[:success] << { row: row[:row], message: 'Moodle group mappings updated' }
      elsif existing_entry
        existing_entry[:message] = "#{existing_entry[:message].to_s.delete_suffix('.')}; Moodle group mappings unchanged"
      elsif existing_type.nil?
        result[:ignored] << { row: row[:row], message: 'No change; Moodle group mappings unchanged' }
      end
    end
    result
  end

  def mapping_errors(mappings)
    errors = []
    campus_mappings = mappings.select { |mapping| mapping.target_type == 'campus' }
    errors << 'Student belongs to multiple mapped campuses' if campus_mappings.map(&:campus_id).uniq.length > 1

    mappings.select { |mapping| mapping.target_type == 'tutorial' }
            .group_by(&:tutorial_stream_id)
            .each_value do |stream_mappings|
      errors << 'Student belongs to multiple Moodle groups mapped to the same tutorial stream' if stream_mappings.length > 1
    end
    mappings.select { |mapping| mapping.target_type == 'group' }
            .group_by(&:group_set_id)
            .each_value do |group_mappings|
      errors << 'Student belongs to multiple Moodle groups mapped to the same group set' if group_mappings.length > 1
    end

    mappings.each do |mapping|
      case mapping.target_type
      when 'group'
        if mapping.create_if_missing?
          if mapping.tutorial.blank? == mapping.tutorial_stream.blank?
            errors << 'Select an existing tutorial or a tutorial stream for the new group'
          end
        elsif mapping.group.blank?
          errors << "Select an existing group in #{mapping.group_set.name}"
        end
      when 'tutorial'
        if !mapping.create_if_missing? && mapping.tutorial.blank?
          errors << "Select an existing tutorial in #{mapping.tutorial_stream.name}"
        end
      end
    end
    errors
  end

  def apply_mappings(project, mappings)
    ActiveRecord::Base.transaction do
      changed = false
      campus = mappings.find { |mapping| mapping.target_type == 'campus' }&.campus
      if campus && project.campus_id != campus.id
        project.update!(campus: campus)
        changed = true
      end

      mappings.select { |mapping| mapping.target_type == 'tutorial' }.each do |mapping|
        tutorial = mapping.tutorial
        if mapping.create_if_missing?
          tutorial = mapping.tutorial_stream.tutorials.where(
            unit: project.unit
          ).where('LOWER(abbreviation) = ?', mapping.moodle_group_name.downcase).first
          tutorial ||= Tutorial.create!(
            unit: project.unit,
            tutorial_stream: mapping.tutorial_stream,
            abbreviation: mapping.moodle_group_name,
            meeting_day: 'Moodle',
            meeting_time: '',
            meeting_location: mapping.moodle_group_name
          )
        end
        if project.tutorial_for_stream(mapping.tutorial_stream)&.id != tutorial.id
          project.enrol_in(tutorial)
          changed = true
        end
      end

      mappings.select { |mapping| mapping.target_type == 'group' }.each do |mapping|
        group = mapping.group
        if mapping.create_if_missing?
          group = mapping.group_set.groups.where('LOWER(name) = ?', mapping.moodle_group_name.downcase).first
          tutorial = group&.tutorial || mapping.tutorial
          if tutorial.blank?
            tutorial = mapping.tutorial_stream.tutorials.where(
              unit: project.unit
            ).where('LOWER(abbreviation) = ?', mapping.moodle_group_name.downcase).first
            tutorial ||= Tutorial.create!(
              unit: project.unit,
              tutorial_stream: mapping.tutorial_stream,
              abbreviation: mapping.moodle_group_name,
              meeting_day: 'Moodle',
              meeting_time: '',
              meeting_location: mapping.moodle_group_name
            )
          end
          group ||= Group.create!(
            group_set: mapping.group_set,
            tutorial: tutorial,
            name: mapping.moodle_group_name
          )
          if project.tutorial_for_stream(tutorial.tutorial_stream)&.id != tutorial.id
            project.enrol_in(tutorial)
            changed = true
          end
        end
        if project.group_for_groupset(mapping.group_set)&.id != group.id
          group.add_member(project)
          changed = true
        end
      end
      changed
    end
  end
end
