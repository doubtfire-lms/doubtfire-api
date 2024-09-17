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
end

Doubtfire::Application.config.institution_settings = InstitutionSettings.new
