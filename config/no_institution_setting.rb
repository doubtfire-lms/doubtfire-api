class InstitutionSettings

  # Used when importing students from a CSV into a unit. This is called to check if
  # the headers in the CSV match an institution system. If this returns true, the import
  # will be processed using the lambdas you specify in the import_settings.
  def are_headers_institution_users?(headers)
    false
  end

  # Returns user import settings for an institution CSV format. When
  # you return true from `are_headers_institution_users?`, these lambdas are used
  # to process the CSV data.
  def user_import_settings_for(headers)
    {
      missing_headers_lambda: ->(row) { headers - row.to_hash.keys }, # lambda to check if row is missing key data. Return a list of missing header names (list of string)
      fetch_row_data_lambda: lambda { |row, unit|
        # Return a hash with the data to import
        {
          unit_code: unit.code,
          username: row["username"],
          student_id: row["student_code"],
          first_name: row["first_name"],
          last_name: row["last_name"],
          nickname: row["preferred_name"],
          email: row["email_address"],
          enrolled: true,
          tutorials: [],
          campus: row["campus"]
        }
      }, # lambda to convert row from csv to required import data (see student list in the sync function). Return a hash of the data.
      replace_existing_tutorial: false, # when true, old tutorials are replaced. When false, if the student already has a tutorial enrolment it is not updated even if different.
      replace_existing_campus: false # as with tutorials, but for campus
    }
  end

  def extract_user_from_row(row)
    {
      unit_code: nil,
      username: nil,
      student_id: nil,
      first_name: nil,
      last_name: nil,
      email: nil,
      tutorials: nil
    }
  end

  # Main entry point for processing - passes in the unit to be synced
  # this should query your institution system and then update enrolments
  # in the unit.
  #
  # You can use the helper method in the unit:
  #
  # unit.sync_enrolment_with(student_list, import_settings, result)
  #
  # `student_list` contains the list of changes to make. Each item is the list is a hash representing a unique student.
  # The has should contain the following keys:
  #   - :row the string data associated with the change for error reporting
  #   - :username
  #   - :student_id
  #   - :first_name
  #   - :last_name
  #   - :nickname
  #   - :email
  #   - :tutorial_codes - a list of tutorial codes. These should already exist. The student will be enrolled in all tutorials passed in.
  #   - :enrolled (boolean) - true if the student should be enrolled, false to withdraw the student
  #   - :campus
  #
  # `import_settings` is a hash with the following keys:
  #   - :missing_headers_lambda - lambda to check if row is missing key data
  #   - :fetch_row_data_lambda - lambda to convert row from csv to required import data
  #   - :replace_existing_tutorial - boolean to indicate if tutorials in csv override ones in doubtfire
  #   - :replace_existing_campus - boolean to indicate if campus in csv override ones in doubtfire
  #
  # For this sync, the main settings would be replace_existing_tutorial and replace_existing_campus. The other settings are used when importing from CSV.
  #

  def sync_enrolments(unit)
    # rubocop:disable Rails/Output
    puts 'Unit sync not enabled'
    # rubocop:enable Rails/Output
  end

  def details_for_next_tutorial_stream(unit, activity_type)
    counter = 1

    begin
      name = "#{activity_type.name} #{counter}"
      abbreviation = "#{activity_type.abbreviation} #{counter}"
      counter += 1
    end while unit.tutorial_streams.where("abbreviation = :abbr OR name = :name", abbr: abbreviation, name: name).present?

    [name, abbreviation]
  end

  def map_saml_response_to_user_id(response)
    login_id = response.name_id || response.nameid
    {
      login_id: login_id,
      email: login_id,
      username: login_id[/(.*)@/, 1] # Get username from email
    }
  end

  # Read details from the SAML response and store in the user fields
  def update_user_from_saml_response(user, user_id_data, response)
    attributes = response.attributes

    # Setup user id details - should all be set...
    user.login_id = user_id_data[:login_id]
    user.email = user_id_data[:email]
    user.username = user_id_data[:username]

    user.first_name = (attributes.fetch(/givenname/) || attributes.fetch(/cn/)).capitalize
    user.last_name = attributes.fetch(/surname/).capitalize
    user.nickname = user.first_name

    # Get the role from the attributes - or set to none = student
    role_response = attributes.fetch(/role/) || attributes.fetch(/userRole/) || []
    user.role_id = role_response.include?('Staff') ? Role.tutor.id : Role.student.id

    user
  end

  def update_user_from_lti_response(user, user_id_data, member)
    user.login_id = user_id_data[:login_id]
    user.email = user_id_data[:email]
    user.username = user_id_data[:username]

    # Update new user with details from the LTI payload
    first_name = member["given_name"] || member["family_name"]
    last_name = member["family_name"] || member["given_name"]
    nickname = member["name"] || first_name

    first_name ||= last_name
    last_name ||= first_name
    nickname ||= first_name

    user.first_name = first_name.squish.capitalize
    user.last_name = last_name.squish.capitalize
    user.nickname = nickname.squish.capitalize

    user.role = should_employ_lti_member(member) || Role.student

    # Assigning tutors automatically:
    # if member['roles'].include?('Instructor')
    #       user.role_id = Role.tutor.id
    # end

    user
  end

  # If this returns nil, LTI will move on to check if this member should be enrolled as a student
  def should_employ_lti_member(member)
    return nil if member['roles'].include?('Student') || member['roles'].include?('Learner')
    return Role.convenor if member['roles'].include?("http://purl.imsglobal.org/vocab/lis/v2/person#Administrator")
    return Role.tutor if member['roles'].include?("Instructor")

    nil
  end

  def should_enrol_lti_member(member)
    # Example "roles" for a Student => ["Learner"]
    # Example "roles" for an Instructor, who is a global Administrator => ["Instructor", "http://purl.imsglobal.org/vocab/lis/v2/person#Administrator"],

    # Only enrol course members who are Students/Learners
    return true if member['roles'].include?('Student') || member['roles'].include?('Learner')
    false
  end

end

Doubtfire::Application.config.institution_settings = InstitutionSettings.new
