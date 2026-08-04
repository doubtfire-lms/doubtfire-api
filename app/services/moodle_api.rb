# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class MoodleApi
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: nil)
      @code = code
      super(message)
    end
  end

  def initialize(integration)
    @integration = integration
  end

  def assignments
    request('mod_assign_get_assignments', 'courseids[0]' => @integration.course_id)
  end

  def students
    request(
      'core_enrol_get_enrolled_users',
      'courseid' => @integration.course_id,
      'options[0][name]' => 'onlyactive',
      'options[0][value]' => 1
    )
  end

  def user_flags(assignment_id = @integration.assignment_id)
    request('mod_assign_get_user_flags', 'assignmentids[0]' => assignment_id)
  end

  def participant(assignment_id, user_id)
    request('mod_assign_get_participant', 'assignid' => assignment_id, 'userid' => user_id, 'embeduser' => 0)
  end

  def course_groups
    request('core_group_get_course_groups', 'courseid' => @integration.course_id)
  end

  def test_connection(progress_callback: nil)
    results = []
    progress_callback&.call(1, 'Fetching course assignments')
    assignment_response = test_function(results, 'mod_assign_get_assignments') { assignments }
    progress_callback&.call(2, 'Fetching enrolled users')
    enrolled_users = test_function(results, 'core_enrol_get_enrolled_users') { students }

    course = Array(assignment_response&.fetch('courses', nil)).find do |item|
      item['id'].to_i == @integration.course_id
    end
    available_assignments = Array(course&.fetch('assignments', nil))
    assignment_id = @integration.assignment_id || available_assignments.first&.fetch('id', nil)
    participant_user = Array(enrolled_users).find do |user|
      Array(user['roles']).any? { |role| role['shortname'] == 'student' }
    end

    progress_callback&.call(3, 'Testing assignment flag access')

    test_function(results, 'mod_assign_get_user_flags') do
      raise Error, 'No assignment is available to test this permission' if assignment_id.blank?

      user_flags(assignment_id)
    end
    progress_callback&.call(4, 'Tested get participant access')
    test_function(results, 'mod_assign_get_participant', successful_error_codes: ['userisfilteredout']) do
      if assignment_id.blank? || participant_user.blank?
        raise Error, 'An assignment and enrolled student are required to test this permission'
      end

      participant(assignment_id, participant_user['id'])
    end

    progress_callback&.call(5, 'Fetching course groups')
    groups = test_function(results, 'core_group_get_course_groups') { course_groups }
    available_groups = Array(groups)

    {
      course: course&.slice('id', 'fullname', 'shortname'),
      assignments: available_assignments.map { |item| item.slice('id', 'name', 'duedate') },
      groups: available_groups.map { |item| item.slice('id', 'name', 'idnumber') },
      permissions: results
    }
  end

  private

  def test_function(results, function, successful_error_codes: [])
    response = yield
    results << { function: function, success: true }
    response
  rescue Error => e
    result = if successful_error_codes.include?(e.code)
               { function: function, success: true, message: e.message }
             else
               { function: function, success: false, error: e.message }
             end
    results << result
    nil
  end

  def request(function, params)
    raise Error, 'DF_MOODLE_API_URL is not configured' if Doubtfire::Application.config.moodle_api_url.blank?

    base_url = Doubtfire::Application.config.moodle_api_url.sub(%r{/+\z}, '')
    endpoint = base_url.end_with?('/webservice/rest/server.php') ? base_url : "#{base_url}/webservice/rest/server.php"
    response = Net::HTTP.post_form(
      URI.parse(endpoint),
      {
        'wstoken' => @integration.api_key,
        'wsfunction' => function,
        'moodlewsrestformat' => 'json'
      }.merge(params.transform_values(&:to_s))
    )
    payload = JSON.parse(response.body)

    if payload.is_a?(Hash) && payload['exception']
      raise Error.new(
        payload['message'] || payload['errorcode'] || 'Moodle rejected the request',
        code: payload['errorcode']
      )
    end
    raise Error, "Moodle returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    payload
  rescue JSON::ParserError
    raise Error, 'Moodle returned an invalid response'
  rescue URI::InvalidURIError
    raise Error, 'DF_MOODLE_API_URL is invalid'
  rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "Unable to connect to Moodle: #{e.message}"
  end
end
