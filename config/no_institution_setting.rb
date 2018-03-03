
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
end

Doubtfire::Application.config.institution_settings = InstitutionSettings.new