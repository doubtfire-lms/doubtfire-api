# frozen_string_literal: true

#
# Reads LMS course data through the LTI service.
#
# Names and Role Provisioning is the baseline and works with any LTI 1.3 platform. When the
# Moodle OnTrack course-data plugin is available, members gain student ids, enrolment state and
# groups, and assignments with extensions become available.
#
# Another source, such as a direct Moodle web service client, only needs to provide the same
# public methods and be returned from LmsIntegration.data_source_for.
#
class LtiCourseDataSource
  class Error < StandardError; end

  def initialize(unit)
    @unit = unit
    @server = LtiServer.new(unit.id)
  end

  def link
    @link = @server.link unless defined?(@link)
    @link
  rescue LtiServer::Error => e
    raise Error, e.message
  end

  def linked?
    link.present?
  end

  def course_data_available?
    link.present? && link['courseDataAvailable'] == true
  end

  # Members of the LMS course, including staff. Each member keeps its Names and Roles fields so
  # institution settings can decide how to employ or enrol them.
  def members
    require_link!
    membership = @server.members
    plugin_users = {}
    group_ids_by_user = Hash.new { |hash, key| hash[key] = [] }

    data = optional_course_data(%w[users groups])
    if data
      Array(data['users']).each { |user| plugin_users[user['id'].to_s] = user }
      Array(data['groups']).each do |group|
        Array(group['member_user_ids']).each { |user_id| group_ids_by_user[user_id.to_s] << group['id'].to_i }
      end
    end

    Array(membership['members']).map do |member|
      user_id = member['user_id'].to_s
      plugin_user = plugin_users[user_id]
      # The plugin's username is the same LMS username, for platforms that leave it out of Names and Roles
      lms_username = member['ext_user_username'].presence || plugin_user&.fetch('username', nil)
      {
        lms_user_id: user_id,
        login_id: UserIdentity.lti_user_id_data(member.merge('ext_user_username' => lms_username))[:login_id],
        email: member['email'].presence || plugin_user&.fetch('email', nil),
        name: member['name'],
        first_name: member['given_name'].presence || plugin_user&.fetch('first_name', nil),
        last_name: member['family_name'].presence || plugin_user&.fetch('last_name', nil),
        student_id: plugin_user&.fetch('idnumber', nil).presence,
        lis_person_sourcedid: member['lis_person_sourcedid'].presence,
        roles: Array(member['roles']),
        active: member_active?(member, plugin_user),
        group_ids: group_ids_by_user[user_id],
        member: member
      }
    end
  rescue LtiServer::Error => e
    raise Error, e.message
  end

  def groups
    course_data_snapshot(%w[groups]).fetch('groups', []).map do |group|
      { id: group['id'].to_i, name: group['name'], idnumber: group['idnumber'] }
    end
  end

  def assignments
    course_data_snapshot(%w[assignments]).fetch('assignments', []).map do |assignment|
      { id: assignment['id'].to_i, name: assignment['name'], due_date: assignment['due_date'].to_i }
    end
  end

  def course
    require_link!
    details = {
      context_id: link['contextId'],
      label: link['contextLabel'],
      title: link['contextTitle'],
      start_date: nil,
      end_date: nil
    }
    data = optional_course_data(%w[groups])
    return details unless data

    context = data['context'] || {}
    details.merge(
      label: context['label'].presence || details[:label],
      title: context['title'].presence || details[:title],
      start_date: context['start_date'].to_i.positive? ? context['start_date'].to_i : nil,
      end_date: context['end_date'].to_i.positive? ? context['end_date'].to_i : nil
    )
  rescue LtiServer::Error => e
    raise Error, e.message
  end

  # The assignment with its per-user extension dates, keyed by LMS user id.
  def assignment_extensions(assignment_id)
    data = course_data_snapshot(%w[users assignments], assignment_id: assignment_id)
    assignment = Array(data['assignments']).find { |item| item['id'].to_i == assignment_id.to_i }
    raise Error, 'The selected assignment was not found in the LMS course' if assignment.blank?

    users = Array(data['users']).index_by { |user| user['id'].to_s }
    {
      assignment: { id: assignment['id'].to_i, name: assignment['name'], due_date: assignment['due_date'].to_i },
      extensions: Array(assignment['extensions']).map do |extension|
        user = users[extension['user_id'].to_s]
        {
          lms_user_id: extension['user_id'].to_s,
          login_id: user&.fetch('username', nil),
          email: user&.fetch('email', nil),
          extension_due_date: extension['extension_due_date'].to_i
        }
      end
    }
  end

  private

  def require_link!
    raise Error, 'This unit is not linked to an LMS course. Link it by launching OnTrack from the LMS.' unless linked?
  end

  def require_course_data!
    require_link!
    return if course_data_available?

    raise Error, 'The Moodle OnTrack course-data plugin is not available for this course.'
  end

  # Plugin data, or nil so callers fall back to Names and Roles when the plugin has been removed.
  def optional_course_data(include)
    return nil unless course_data_available?

    @server.course_data(include: include)
  rescue LtiServer::Error => e
    raise unless e.status == 422

    link['courseDataAvailable'] = false
    nil
  end

  def course_data_snapshot(include, assignment_id: nil)
    require_course_data!
    @server.course_data(include: include, assignment_id: assignment_id)
  rescue LtiServer::Error => e
    link['courseDataAvailable'] = false if e.status == 422
    raise Error, e.message
  end

  def member_active?(member, plugin_user)
    return false unless member['status'].blank? || member['status'] == 'Active'
    return true if plugin_user.nil?

    !plugin_user['suspended'] && !plugin_user['deleted'] && Array(plugin_user['enrolments']).any? { |enrolment| enrolment['active'] }
  end
end
