# frozen_string_literal: true

#
# Imports LMS course members into a unit. Based on ImportStudentsLtiJob, but reads members through
# the unit's LMS data source so it can run from OnTrack or on a schedule without an LTI launch.
#
# The LMS is the source of truth: when withdrawing is enabled, enrolled students who are no longer
# active students in the LMS are withdrawn, and returning students are re-enrolled.
#
class ImportLmsStudentsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include LtiHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, preview_only, withdraw_missing, scheduled)
    at(0, 'Fetching LMS course members')
    total(0)

    unit = Unit.find(unit_id)
    integration = unit.lms_integration
    source = LmsIntegration.data_source_for(unit)
    mappings = student_mappings(integration, source)
    members = source.members
    settings = Doubtfire::Application.config.institution_settings
    total(members.length)

    result = { success: [], ignored: [], errors: [] }
    active_student_user_ids = Set.new
    active_student_count = 0
    incomplete_member_count = 0

    members.each_with_index do |lms_member, index|
      at(index, 'Importing members')
      member_mappings = lms_member[:group_ids].flat_map { |group_id| mappings.fetch(group_id, []) }
      row = display_row(unit, lms_member, member_mappings)

      begin
        member = lms_member[:member]
        valid_member, missing = valid_lti_member?(member)
        unless valid_member
          incomplete_member_count += 1
          result[:ignored] << { row: row, message: "Missing required fields: #{missing.join(', ')}" }
          next
        end

        staff_role = settings.should_employ_lti_member(member)
        enrol = settings.should_enrol_lti_member(member)
        if staff_role.nil? && !enrol
          result[:ignored] << { row: row, message: 'Not a student or staff member' }
          next
        end

        unless lms_member[:active]
          result[:ignored] << { row: row, message: 'Inactive in the LMS' }
          next
        end

        user = UserIdentity.find_user(login_id: lms_member[:login_id], email: lms_member[:email])
        active_student_count += 1 if enrol
        active_student_user_ids << user.id if enrol && user

        # Still counted as active above, so an account we cannot trust is never withdrawn
        if user && UserIdentity.blocked?(user, login_id: lms_member[:login_id], email: lms_member[:email], source: 'lms_import')
          result[:errors] << { row: row, message: "#{user.username} is linked to a different login id" }
          next
        end

        mapping_errors = enrol ? LmsGroupMappingApplier.mapping_errors(member_mappings) : []
        if preview_only
          record_preview(result, unit, row, user, staff_role, enrol, mapping_errors)
        else
          user ||= create_user(settings, lms_member)
          UserIdentity.link_identity(user, login_id: lms_member[:login_id])
          active_student_user_ids << user.id if enrol
          import_member(result, unit, row, user, staff_role, enrol, member_mappings, mapping_errors)
        end
      rescue StandardError => e
        result[:errors] << { row: row, message: e.message }
      end
    end

    if withdraw_missing
      withdraw_missing_students(result, unit, active_student_user_ids, active_student_count, incomplete_member_count, preview_only)
    end

    store(result: result.to_json)
    integration&.auto_sync_succeeded! if scheduled
  rescue StandardError => e
    LmsIntegration.find_by(unit_id: unit_id)&.auto_sync_failed!(:students, e) if scheduled
    raise
  end

  private

  def student_mappings(integration, source)
    return {} unless integration&.group_mapping_enabled? && source.course_data_available?

    at(0, 'Validating LMS group mappings')
    LmsIntegrationValidator.new(integration).validate!(
      groups: source.groups,
      assignments: integration.fetch_extensions? ? source.assignments : []
    )
    integration.lms_group_mappings.includes(:group_set, :group, :campus, :tutorial_stream, :tutorial)
               .group_by(&:lms_group_id)
  rescue LtiCourseDataSource::Error
    raise if source.course_data_available?

    {}
  end

  def display_row(unit, lms_member, mappings)
    {
      unit_code: unit.code,
      lms_username: lms_member[:login_id],
      student_id: lms_member[:student_id],
      lis_person_sourcedid: lms_member[:lis_person_sourcedid],
      first_name: lms_member[:first_name],
      last_name: lms_member[:last_name],
      email: lms_member[:email],
      lms_roles: lms_member[:roles].join(', '),
      lms_groups: mappings.map(&:lms_group_name).uniq.join("\n"),
      mapped_campus: mappings.filter_map { |mapping| mapping.campus&.name }.uniq.join(', '),
      mapped_tutorial: mappings.select { |mapping| mapping.target_type == 'tutorial' }.map { |mapping| mapping.tutorial&.abbreviation || mapping.lms_group_name }.uniq.join(', '),
      mapped_group: mappings.select { |mapping| mapping.target_type == 'group' }.map { |mapping| mapping.group&.name || mapping.lms_group_name }.uniq.join(', ')
    }
  end

  def create_user(settings, lms_member)
    user_id_data = UserIdentity.user_id_data(login_id: lms_member[:login_id], email: lms_member[:email])
    user = User.create! do |new_user|
      settings.update_user_from_lti_response(new_user, user_id_data, lms_member[:member])
    end
    user.update!(student_id: lms_member[:student_id]) if lms_member[:student_id].present? && user.student_id.blank?
    user
  end

  def record_preview(result, unit, row, user, staff_role, enrol, mapping_errors)
    messages = []
    messages << "Would add staff (#{staff_role.name})" if staff_role && (user.nil? || unit.unit_role_for(user).nil?)

    if enrol
      project = user && unit.projects.find_by(user_id: user.id)
      messages << if user.nil?
                    'Would create user and enrol student'
                  elsif project.nil?
                    'Would enrol student'
                  elsif !project.enrolled
                    'Would re-enrol student'
                  end
    end
    messages.compact!

    if mapping_errors.any?
      result[:errors] << { row: row, message: mapping_errors.join('; ') }
    elsif messages.any?
      result[:success] << { row: row, message: messages.join('; ') }
    else
      result[:ignored] << { row: row, message: 'No change' }
    end
  end

  def import_member(result, unit, row, user, staff_role, enrol, mappings, mapping_errors)
    messages = []
    if staff_role && unit.unit_role_for(user).nil?
      staff = unit.employ_staff(user, staff_role)
      messages << "Added staff (#{staff_role.name})" if staff&.persisted?
    end

    if enrol
      project = unit.projects.find_by(user_id: user.id)
      was_enrolled = project&.enrolled
      project = unit.enrol_student(user, project&.campus)
      messages << (was_enrolled.nil? ? 'Enrolled student' : 'Re-enrolled student') unless was_enrolled

      if mapping_errors.any?
        result[:errors] << { row: row, message: ([messages.join('; ')].compact_blank + mapping_errors).join('; ') }
        return
      end
      messages << 'LMS group mappings updated' if mappings.any? && LmsGroupMappingApplier.apply(project, mappings)
    end

    if messages.any?
      result[:success] << { row: row, message: messages.join('; ') }
    else
      result[:ignored] << { row: row, message: 'No change' }
    end
  end

  def withdraw_missing_students(result, unit, active_student_user_ids, active_student_count, incomplete_member_count, preview_only)
    # Incomplete or empty member data usually means LMS privacy or link settings are wrong, so never treat it as students leaving.
    if active_student_count.zero?
      result[:errors] << { row: { unit_code: unit.code }, message: 'No active LMS students were found, so no students were withdrawn' }
      return
    end
    if incomplete_member_count.positive?
      result[:errors] << {
        row: { unit_code: unit.code },
        message: "#{incomplete_member_count} LMS members were missing required details, so no students were withdrawn. Check the tool shares names and emails."
      }
      return
    end

    unit.projects.where(enrolled: true).where.not(user_id: active_student_user_ids.to_a).includes(:user).find_each do |project|
      row = nil
      row = {
        unit_code: unit.code,
        username: project.user.username,
        student_id: project.user.student_id,
        first_name: project.user.first_name,
        last_name: project.user.last_name,
        email: project.user.email
      }
      if preview_only
        result[:success] << { row: row, message: 'Would withdraw: not an active student in the LMS' }
      else
        project.update!(enrolled: false)
        result[:success] << { row: row, message: 'Withdrawn: not an active student in the LMS' }
      end
    rescue StandardError => e
      result[:errors] << { row: row, message: e.message }
    end
  end
end
