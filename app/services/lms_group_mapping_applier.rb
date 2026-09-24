# frozen_string_literal: true

#
# Applies a student's LMS group mappings to their OnTrack project: campus, tutorial enrolments and
# group membership, creating mapped groups and tutorials when a mapping allows it.
#
module LmsGroupMappingApplier
  module_function

  def mapping_errors(mappings)
    errors = []
    campus_mappings = mappings.select { |mapping| mapping.target_type == 'campus' }
    errors << 'Student belongs to multiple mapped campuses' if campus_mappings.map(&:campus_id).uniq.length > 1

    mappings.select { |mapping| mapping.target_type == 'tutorial' }
            .group_by(&:tutorial_stream_id)
            .each_value do |stream_mappings|
      errors << 'Student belongs to multiple LMS groups mapped to the same tutorial stream' if stream_mappings.length > 1
    end
    mappings.select { |mapping| mapping.target_type == 'group' }
            .group_by(&:group_set_id)
            .each_value do |group_mappings|
      errors << 'Student belongs to multiple LMS groups mapped to the same group set' if group_mappings.length > 1
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
        errors << "Select an existing tutorial in #{mapping.tutorial_stream.name}" if mapping.tutorial.blank?
      end
    end
    errors
  end

  # Returns true when the project changed.
  def apply(project, mappings)
    ActiveRecord::Base.transaction do
      changed = false
      campus = mappings.find { |mapping| mapping.target_type == 'campus' }&.campus
      if campus && project.campus_id != campus.id
        project.update!(campus: campus)
        changed = true
      end

      mappings.select { |mapping| mapping.target_type == 'tutorial' }.each do |mapping|
        tutorial = mapping.tutorial
        if project.tutorial_for_stream(mapping.tutorial_stream)&.id != tutorial.id
          project.enrol_in(tutorial)
          changed = true
        end
      end

      mappings.select { |mapping| mapping.target_type == 'group' }.each do |mapping|
        group = mapping.group
        if mapping.create_if_missing?
          group = mapping.group_set.groups.where('LOWER(name) = ?', mapping.lms_group_name.downcase).first
          tutorial = group&.tutorial || mapping.tutorial
          if tutorial.blank?
            tutorial = mapping.tutorial_stream.tutorials.where(
              unit: project.unit
            ).where('LOWER(abbreviation) = ?', mapping.lms_group_name.downcase).first
            tutorial ||= Tutorial.create!(
              unit: project.unit,
              tutorial_stream: mapping.tutorial_stream,
              abbreviation: mapping.lms_group_name,
              meeting_day: 'LMS',
              meeting_time: '',
              meeting_location: mapping.lms_group_name
            )
          end
          group ||= Group.create!(
            group_set: mapping.group_set,
            tutorial: tutorial,
            name: mapping.lms_group_name
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
