class InstitutionSettings
  def are_headers_institution_users?(headers)
    false
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
end

Doubtfire::Application.config.institution_settings = InstitutionSettings.new
