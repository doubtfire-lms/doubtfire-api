# frozen_string_literal: true

#
# Checks saved group mappings and the selected assignment against the live LMS course, so imports
# never apply mappings for groups or assignments that were renamed or deleted in the LMS.
#
class LmsIntegrationValidator
  class ValidationError < LtiCourseDataSource::Error
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super("LMS integration requires review: #{issues.pluck(:message).join('; ')}")
    end
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
      assignments: assignments.map { |assignment| assignment.slice(:id, :name, :due_date) },
      issues: issues,
      notices: notices
    }
  end

  def validate!(groups:, assignments:)
    result = validate(groups: groups, assignments: assignments)
    return result if result[:valid]

    raise ValidationError, result[:issues]
  end

  private

  def group_mapping_issues(groups)
    return [[], []] unless @integration.group_mapping_enabled?

    mappings = @integration.lms_group_mappings.includes(
      :group_set, :group, :campus, :tutorial_stream, :tutorial
    ).to_a
    live_groups = groups.index_by { |group| group[:id].to_i }
    mappings_by_id = mappings.group_by(&:lms_group_id)
    issues = []
    notices = []

    live_groups.each do |id, group|
      group_mappings = mappings_by_id[id]
      if group_mappings.blank?
        issues << {
          type: 'group_missing', lms_group_id: id, lms_group_name: group[:name],
          message: 'This LMS group has no mapping.'
        }
      else
        if group_mappings.many?
          notices << {
            type: 'group_duplicate', lms_group_id: id, lms_group_name: group[:name],
            message: "This LMS group has #{group_mappings.length} mappings; all will be applied."
          }
        end

        group_mappings.each do |mapping|
          if mapping.lms_group_name != group[:name]
            issues << {
              type: 'group_renamed', lms_group_id: id, lms_group_name: group[:name],
              message: "LMS group name changed from “#{mapping.lms_group_name}” to “#{group[:name]}”."
            }
          elsif mapping.invalid?
            issues << {
              type: 'group_invalid', lms_group_id: id, lms_group_name: group[:name],
              message: mapping.errors.full_messages.join(', ')
            }
          end
        end
      end
    end

    mappings.each do |mapping|
      next if live_groups.key?(mapping.lms_group_id)

      issues << {
        type: 'group_deleted', lms_group_id: mapping.lms_group_id,
        lms_group_name: mapping.lms_group_name,
        message: 'This mapped LMS group no longer exists.'
      }
    end

    [issues, notices]
  end

  def assignment_issues(assignments)
    return [] unless @integration.fetch_extensions?

    if @integration.assignment_id.blank? || @integration.assignment_name.blank?
      return [{ type: 'assignment_missing', message: 'Select an LMS assignment.' }]
    end

    assignment = assignments.find { |item| item[:id].to_i == @integration.assignment_id }
    if assignment.blank?
      return [{
        type: 'assignment_deleted', assignment_id: @integration.assignment_id,
        assignment_name: @integration.assignment_name,
        message: "The LMS assignment “#{@integration.assignment_name}” no longer exists."
      }]
    end
    return [] if assignment[:name] == @integration.assignment_name

    [{
      type: 'assignment_renamed', assignment_id: assignment[:id],
      assignment_name: assignment[:name],
      message: "The LMS assignment was renamed from “#{@integration.assignment_name}” to “#{assignment[:name]}”."
    }]
  end
end
