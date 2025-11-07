require 'oauth2'
require 'net/http'
require 'uri'
require 'json'

# Class to load moodle features
#
class MoodleIntegration
  def self.enabled?
    Doubtfire::Application.config.d2l_enabled &&
      Doubtfire::Application.config.d2l_client_id.present? &&
      Doubtfire::Application.config.d2l_client_secret.present? &&
      Doubtfire::Application.config.d2l_redirect_uri.present?
  end

  def self.moodle_api_key
    Doubtfire::Application.config.moodle_api_key
  end

  def self.moodle_api_url
    Doubtfire::Application.config.moodle_api_url
  end

  def self.save_user_extension
    uri = URI("#{moodle_api_url}/webservice/rest/server.php")
    uri.query = URI.encode_www_form({
                                      wstoken: moodle_api_key,
                                      wsfunction: 'mod_assign_save_user_extensions',
                                      moodlewsrestformat: 'json',
                                      assignmentid: 1,
                                      'userids[0]' => 3,
                                      'dates[0]' => 1_763_793_200
                                    })

    res = Net::HTTP.get_response(uri)

    # puts res.code
    # puts res.body
    # puts res.message

    JSON.parse(res.body)
  end

  def self.get_context_users(course_id)
    uri = URI("#{moodle_api_url}/webservice/rest/server.php")
    uri.query = URI.encode_www_form({
                                      wstoken: moodle_api_key,
                                      wsfunction: 'core_enrol_get_enrolled_users',
                                      moodlewsrestformat: 'json',
                                      courseid: course_id
                                    })

    res = Net::HTTP.get_response(uri)

    uri.query = URI.encode_www_form({
                                      wstoken: moodle_api_key,
                                      wsfunction: 'mod_assign_get_assignments',
                                      moodlewsrestformat: 'json',
                                      courseid: course_id
                                    })

    res = Net::HTTP.get_response(uri)

    # puts res.code
    # puts res.body
    # puts res.message

    JSON.parse(res.body)

    # Example output:
    #   [{ "id" => 2,
    #      "username" => "user",
    #      "firstname" => "Admin",
    #      "lastname" => "User",
    #      "fullname" => "Admin User",
    #      "email" => "user@example.com",
    #      "department" => "",
    #      "firstaccess" => 1762488076,
    #      "lastaccess" => 1762491307,
    #      "lastcourseaccess" => 1762491351,
    #      TODO: we can use the role here to import the user a tutor
    #      "roles" => [{ "roleid" => 3, "name" => "", "shortname" => "editingteacher", "sortorder" => 0 }],
    #      "enrolledcourses" => [{ "id" => 2, "fullname" => "FIT1045 Introduction to Programming", "shortname" => "FIT1045" }] },
    #    { "id" => 3,
    #      "username" => "student_1",
    #      "firstname" => "Example",
    #      "lastname" => "Student",
    #      "fullname" => "Example Student",
    #      "email" => "student@example.com",
    #      "department" => "",
    #      "firstaccess" => 0,
    #      "lastaccess" => 0,
    #      "lastcourseaccess" => 0,
    #      "description" => "",
    #      "descriptionformat" => 1,
    #      TODO: we can use the role here to import the user and enrol them as a student
    #      "roles" => [{ "roleid" => 5, "name" => "", "shortname" => "student", "sortorder" => 0 }],
    #      "enrolledcourses" => [{ "id" => 2, "fullname" => "FIT1045 Introduction to Programming", "shortname" => "FIT1045" }] }]

    # TODO: loop through each user, create the user and enrol them into the linked course
    # TODO: The unit details will probably need a field to set the course_id
  end
end
