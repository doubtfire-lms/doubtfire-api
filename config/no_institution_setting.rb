
class InstitutionSettings
    def are_headers_institution_users? (headers)
        false
    end

    def extract_user_from_row(row)
        {
            unit_code:      nil,
            username:       nil,
            student_id:     nil,
            first_name:     nil,
            last_name:      nil,
            email:          nil,
            tutorial_code:  nil
        }
    end

    def sync_enrolments(unit)
      puts 'Unit sync not enabled'
    end

    def name_for_next_tutorial_stream(unit, activity_type)
        "#{activity_type.name} #{unit.tutorial_streams.where(activity_type: activity_type).count + 1}"
    end

    def abbreviation_for_next_tutorial_stream(unit, activity_type)
        "#{activity_type.abbreviation} #{unit.tutorial_streams.where(activity_type: activity_type).count + 1}"
    end
end

Doubtfire::Application.config.institution_settings = InstitutionSettings.new
