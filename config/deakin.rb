require 'rest-client'

#
# This is an institution settings - used for custom imports of users into units.
#
class DeakinInstitutionSettings
  def logger
    Rails.logger
  end

  def initialize()
    @base_url = ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']
    @client_id = ENV['DF_INSTITUTION_SETTINGS_SYNC_CLIENT_ID']
    @client_secret = ENV['DF_INSTITUTION_SETTINGS_SYNC_CLIENT_SECRET']

    @star_url = ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']
    @star_user = ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_USER']
    @star_secret = ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_SECRET']
  end

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

        tutorial_code = fetch_tutorial unit, row

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

    def sync_enrolments(unit)
      logger.info("Starting sync for #{unit.code}")
      result = {
        success: [],
        ignored: [],
        errors:  []
      }

      tp = unit.teaching_period

      unless tp.present?
        logger.error "Failing to sync unit #{unit.code} as not in teaching period"
        return
      end

      begin
        url = "#{@base_url}?academicYear=#{tp.year}&periodType=trimester&period=#{tp.period.last}&unitCode=#{unit.code}"
        logger.info("Requesting #{url}")

        response = RestClient.get(url, headers={ "client_id" => @client_id, "client_secret" => @client_secret})

        if response.code == 200
          jsonData = JSON.parse(response.body)
          if jsonData["unitEnrolments"].nil?
            logger.error "Failed to sync #{unit.code} - No response from #{url}"  
            return
          end

          enrolmentData = jsonData["unitEnrolments"].first
          # Make sure units match
          unless enrolmentData['unitCode'] == unit.code
            logger.error "Failed to sync #{unit.code} - response had unit code #{enrolmentData['unitCode']}"  
            return
          end

          # Make sure correct trimester
          unless enrolmentData['teachingPeriod']['year'].to_i == tp.year && "#{enrolmentData['teachingPeriod']['type'][0].upcase}#{enrolmentData['teachingPeriod']['period']}" == tp.period
            logger.error "Failed to sync #{unit.code} - response had trimester #{enrolmentData['teachingPeriod']}"  
            return
          end

          logger.info "Syncing enrolment for #{unit.code} - #{tp.year} #{tp.period}"

          # Get the list of students
          student_list = []

          timetable_data = fetch_timetable_data(unit)

          enrolmentData['locations'].each do |location|
            logger.info " - Syncing #{location['name']}"

            location['enrolments'].each do |enrolment|
              if enrolment['email'].nil?
                # Only error if they were enrolled
                if ['ENROLLED', 'COMPLETED'].include?(enrolment['status'].upcase)
                  result[:errors] << { row: enrolment, message: 'Missing email and username!' }
                else
                  result[:ignored] << { row: enrolment, message: 'Not enrolled, but no email/username' }
                end

                next
              end

              row_data = {
                unit_code:      enrolmentData['unitCode'],
                username:       enrolment['email'][/[^@]+/],
                student_id:     enrolment['studentId'],
                first_name:     enrolment['givenNames'],
                last_name:      enrolment['surname'],
                nickname:       enrolment['preferredName'],
                email:          enrolment['email'],
                enrolled:       ['ENROLLED', 'COMPLETED'].include?(enrolment['status'].upcase),
                tutorial_code:  location['name'].upcase == 'CLOUD (ONLINE)' ? 'Cloud' : timetable_data[enrolment['studentId']],
                row:            enrolment
              }
              
              if row_data[:tutorial_code] == 'Cloud' && unit.week_number(Time.zone.now) < 4 && unit.tutorials.where(abbreviation: 'Cloud').count == 0
                unit.add_tutorial(
                  'Asynchronous',
                  '9:00',
                  'Online',
                  unit.main_convenor,
                  'Cloud'
                )
              end

              student_list << row_data
            end
          end

          import_settings = {
            replace_existing_tutorial: false
          }

          # Now get unit to sync
          unit.sync_enrolment_with(student_list, import_settings, result)
        else
          logger.error "Failed to sync #{unit.code} - #{response}"
        end

      rescue Exception => e
        logger.error "Failed to sync unit: #{e.message}"
      end
      result
    end

    def fetch_timetable_data(unit)
      logger.info("Fetching STAR data for #{unit.code}")

      result = {}

      tp = unit.teaching_period

      activity_types = [
        'Wrk',
        'Prc',
        'Sem'
      ]

      url = "#{@star_url}/star-#{tp.year}/rest/students/allocated"

      activity_types.each do |activity_type|
        logger.info("Fetching #{activity_type} from #{url}")
        response = RestClient.post(url, {username: @star_user, password: @star_secret, where_clause:"subject_code LIKE '#{unit.code}%' AND activity_group_code LIKE '#{activity_type}01'"})

        if response.code == 200
          jsonData = JSON.parse(response.body)

          # Switch to the next activity type if this one is empty
          next if jsonData['allocations'].count == 0

          jsonData['allocations'].each do |allocation|
            result[allocation['student_code'].to_i] = fetch_tutorial(unit, allocation) unless allocation['student_code'].nil?
          end

          # Quit now... we have the matching activity
          return result
        end
      end

      result
    end

    def fetch_tutorial(unit, star_data)
      tutorial_code = star_data["campus"].strip() == "" ? nil : "#{star_data["campus"]}-#{star_data["activity_code"]}"

      unless tutorial_code.nil?
        if unit.tutorials.where(abbreviation: tutorial_code).count == 0 && star_data['subject_code'].starts_with?(unit.code)
          
          if unit.week_number(Time.zone.now) < 4
            unit.add_tutorial(
              day_abbr_to_name(star_data["day_of_week"]),
              star_data["start_time"],
              star_data["location"],
              unit.main_convenor,
              tutorial_code
            )
          else
            tutorial_code = nil
          end
        end
      end

      tutorial_code
    end
end

Doubtfire::Application.config.institution_settings = DeakinInstitutionSettings.new
