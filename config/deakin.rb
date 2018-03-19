#
# This is an institution settings - used for custom imports of users into units.
#
class DeakinInstitutionSettings

    def are_callista_headers? (headers)
        headers[0] == "person id" && headers.count == 35
    end

    def are_star_headers? (headers)
        headers.include?("student_code") && headers.count == 11
    end

    def are_headers_institution_users? (headers)
        are_callista_headers?(headers) || are_star_headers?(headers)
    end

    def missing_headers(row, headers)
        headers - row.to_hash.keys
    end

    def user_import_settings_for(headers)
        if are_callista_headers?(headers)
            {
                missing_headers_lambda: ->(row) {
                    missing_headers(row, ["person id", "surname", "given names", "unit code", "student attempt status", "email", "preferred given name"])
                },
                fetch_row_data_lambda: ->(row, unit) { fetch_callista_row(row, unit) },
                replace_existing_tutorial: false
            }
        else
            {
                missing_headers_lambda: ->(row) {
                    missing_headers(row, ["student_code","first_name","last_name","email_address","preferred_name","subject_code","activity_code","campus","day_of_week","start_time","location"])
                },
                fetch_row_data_lambda: ->(row, unit) { fetch_star_row(row, unit) },
                replace_existing_tutorial: true
            }
        end
    end
    
    def day_abbr_to_name(day)
        case day
            when 'mon'
                'Monday'
            when 'tue'
                'Tuesday'
            when 'wed'
                'Wednesday'
            when 'thu'
                'Thursday'
            when 'fri'
                'Friday'
            else
                day
        end
    end

    def fetch_star_row(row, unit)
        email_match = /(.*)(?=@)/.match( row["email_address"] )
        subject_match = /.*?(?=_)/.match( row["subject_code"] )
        username = email_match.nil? ? nil : email_match[0]
        unit_code = subject_match.nil? ? nil : subject_match[0]

        tutorial_code = row["campus"].strip() == "" ? nil : "#{row["campus"]}-#{row["activity_code"]}"

        unless tutorial_code.nil?
            if unit.tutorials.where(abbreviation: tutorial_code).count == 0 && unit_code == unit.code
                unit.add_tutorial(
                    day_abbr_to_name(row["day_of_week"]),
                    row["start_time"],
                    row["location"],
                    unit.main_convenor,
                    tutorial_code
                )
            end
        end

        {
            unit_code:      unit_code,
            username:       username,
            student_id:     row["student_code"],
            first_name:     row["first_name"],
            last_name:      row["last_name"],
            nickname:       row["preferred_name"] == '-' ? nil : row["preferred_name"],
            email:          row["email_address"],
            enrolled:       true,
            tutorial_code:  tutorial_code
        }
    end

    def fetch_callista_row(row, unit)
        if unit.tutorials.where(abbreviation: 'Cloud').count == 0
            unit.add_tutorial(
                'Monday',
                '8:00am',
                'Cloud',
                unit.main_convenor,
                'Cloud'
            )
        end

        {
            unit_code:      row["unit code"],
            username:       row["email"],
            student_id:     row["person id"],
            first_name:     row["given names"],
            last_name:      row["surname"],
            nickname:       row["preferred given name"] == "-" ? nil : row["preferred given name"],
            email:          "#{row["email"]}@deakin.edu.au",
            enrolled:       row["student attempt status"] == 'ENROLLED',
            tutorial_code:  row["unit mode"] == 'OFF' ? "Cloud" : nil
        }
    end

end

Doubtfire::Application.config.institution_settings = DeakinInstitutionSettings.new