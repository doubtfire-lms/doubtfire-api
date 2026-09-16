# frozen_string_literal: true

class MoodleIntegrationValidator
  def self.assignments_for_course(integration, response)
    course = Array(response&.fetch('courses', nil)).find do |item|
      item['id'].to_i == integration.course_id
    end
    Array(course&.fetch('assignments', nil))
  end

  def initialize(integration)
    @integration = integration
  end

  def validate(groups:, assignments:, record_success: true)
    groups = Array(groups).map(&:with_indifferent_access)
    assignments = Array(assignments).map(&:with_indifferent_access)
    group_issues, notices = group_mapping_issues(groups)
    issues = group_issues + assignment_issues(assignments)
    valid = issues.empty?
    validated_at = valid ? Time.current : nil

    if record_success || !valid
      @integration.update!(validated: valid, validated_at: validated_at)
    end

    {
      valid: valid,
      validated_at: validated_at,
      groups: groups.map { |group| group.slice(:id, :name, :idnumber) },
      assignments: assignments.map { |assignment| assignment.slice(:id, :name, :duedate) },
      issues: issues,
      notices: notices
    }
  end

  def validate!(groups:, assignments:)
    result = validate(groups: groups, assignments: assignments)
    return result if result[:valid]

    raise MoodleApi::Error, "Moodle integration requires review: #{result[:issues].pluck(:message).join('; ')}"
  end

  private

  def group_mapping_issues(groups)
    mappings = @integration.moodle_group_mappings.includes(
      :group_set, :group, :campus, :tutorial_stream, :tutorial
    ).to_a
    live_groups = groups.index_by { |group| group[:id].to_i }
    mappings_by_id = mappings.group_by(&:moodle_group_id)
    issues = []
    notices = []

    issues << { type: 'group_mapping_disabled', message: 'Enable group mapping before validation.' } unless @integration.group_mapping_enabled?

    live_groups.each do |id, group|
      group_mappings = mappings_by_id[id]
      if group_mappings.blank?
        issues << {
          type: 'group_missing', moodle_group_id: id, moodle_group_name: group[:name],
          message: 'This Moodle group has no mapping.'
        }
      else
        if group_mappings.many?
          notices << {
            type: 'group_duplicate', moodle_group_id: id, moodle_group_name: group[:name],
            message: "This Moodle group has #{group_mappings.length} mappings; all will be applied."
          }
        end

        group_mappings.each do |mapping|
          if mapping.moodle_group_name != group[:name]
            issues << {
              type: 'group_renamed', moodle_group_id: id, moodle_group_name: group[:name],
              message: "Moodle group name changed from “#{mapping.moodle_group_name}” to “#{group[:name]}”."
            }
          elsif mapping.invalid?
            issues << {
              type: 'group_invalid', moodle_group_id: id, moodle_group_name: group[:name],
              message: mapping.errors.full_messages.join(', ')
            }
          end
        end
      end
    end

    mappings.each do |mapping|
      next if live_groups.key?(mapping.moodle_group_id)

      issues << {
        type: 'group_deleted', moodle_group_id: mapping.moodle_group_id,
        moodle_group_name: mapping.moodle_group_name,
        message: 'This mapped Moodle group no longer exists.'
      }
    end

    [issues, notices]
  end

  def assignment_issues(assignments)
    return [] unless @integration.fetch_extensions?

    if @integration.assignment_id.blank? || @integration.assignment_name.blank?
      return [{ type: 'assignment_missing', message: 'Select a Moodle assignment.' }]
    end

    assignment = assignments.find { |item| item[:id].to_i == @integration.assignment_id }
    if assignment.blank?
      return [{
        type: 'assignment_deleted', assignment_id: @integration.assignment_id,
        assignment_name: @integration.assignment_name,
        message: "The Moodle assignment “#{@integration.assignment_name}” no longer exists."
      }]
    end
    return [] if assignment[:name] == @integration.assignment_name

    [{
      type: 'assignment_renamed', assignment_id: assignment[:id],
      assignment_name: assignment[:name],
      message: "The Moodle assignment was renamed from “#{@integration.assignment_name}” to “#{assignment[:name]}”."
    }]
  end
end
