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
          missing_headers(row, ["person id", "surname", "given names", "unit code", "student attempt status", "email", "preferred given name", "campus"])
        },
        fetch_row_data_lambda: ->(row, unit) { fetch_callista_row(row, unit) },
        replace_existing_tutorial: false
      }
    else
      {
        missing_headers_lambda: ->(row) {
          missing_headers(row, ["student_code","first_name","last_name","email_address","preferred_name","subject_code","activity_code","campus","day_of_week","start_time","location", "campus"])
        },
        fetch_row_data_lambda: ->(row, unit) { fetch_star_row(row, unit) },
        replace_existing_tutorial: true
      }
    end
  end

  def day_abbr_to_name(day)
    case day.downcase
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

  def activity_type_for_group_code (activity_group_code, description)
    result = ActivityType.where('lower(abbreviation) = :abbr', abbr: activity_group_code[0...-2].downcase).first

    if result.nil?
      name = description[0...-2]
      abbr = activity_group_code[0...-2]

      result = ActivityType.create!(name: name, abbreviation: abbr)
    end

    result
  end

  def default_cloud_campus_abbr
    'Cloud-01'
  end

  # Doubtfire::Application.config.institution_settings.sync_streams_from_star(Unit.last)
  def sync_streams_from_star(unit)
    result = {}

    tp = unit.teaching_period

    url = "#{@star_url}/star-#{tp.year}/rest/activities"

    logger.info("Fetching #{unit.name} timetable from #{url}")
    response = RestClient.post(url, {username: @star_user, password: @star_secret, where_clause:"subject_code LIKE '#{unit.code}%'"})

    if response.code == 200
      jsonData = JSON.parse(response.body)
      if jsonData["activities"].nil?
        logger.error "Failed to sync #{unit.code} - No response from #{url}"
        return
      end

      activityData = jsonData["activities"]

      activityData.each do |activity|
        # Make sure units match
        subject_match = /.*?(?=_)/.match( activity["subject_code"] )
        unit_code = subject_match.nil? ? nil : subject_match[0]
        unless unit_code == unit.code
          logger.error "Failed to sync #{unit.code} - response had unit code #{enrolmentData['unitCode']}"
          return
        end

        stream = unit.tutorial_streams.where(abbreviation: activity['activity_group_code']).first

        # Skip classes - unless it is in the unit's current streams
        next if stream.nil? && activity_type_for_group_code(activity['activity_group_code'], activity['description']).abbreviation == 'Cls'

        if stream.nil?
          stream = unit.add_tutorial_stream activity['description'], activity['activity_group_code'], activity_type_for_group_code(activity['activity_group_code'], activity['description'])
        end

        campus = Campus.find_by(abbreviation: activity['campus'])

        abbr = tutorial_abbr_for_star(activity)
        tutorial = unit.tutorials.where(abbreviation: abbr, campus_id: campus.id).first
        if tutorial.nil?
          unit.add_tutorial(
            activity['day_of_week'], #day
            activity['start_time'], #time
            activity['location'], #location
            unit.main_convenor_user, #tutor
            campus, #campus
            -1, #capacity
            abbr, #abbrev
            stream #tutorial_stream=nil
          )
        end
      end
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
      tutorials:      tutorial_code.present? ? [ tutorial_code ] : [],
      campus:         row["campus"]
    }
  end

  def map_callista_to_campus(row)
    key = row["unit mode"] == 'OFF' ? 'C' : row['unit location']
    Campus.find_by(abbreviation: key)
  end

  def cloud_campus
    Campus.find_by(abbreviation: 'C')
  end

  def fetch_callista_row(row, unit)
    campus = map_callista_to_campus(row)

    result = {
      unit_code:      row["unit code"],
      username:       row["email"],
      student_id:     row["person id"],
      first_name:     row["given names"],
      last_name:      row["surname"],
      nickname:       row["preferred given name"] == "-" ? nil : row["preferred given name"],
      email:          "#{row["email"]}@deakin.edu.au",
      enrolled:       row["student attempt status"] == 'ENROLLED',
      campus:         campus.name,
      tutorials:      []
    }

    sync_student_user_from_callista(result)
    result
  end

  #
  # Ensure that changes in email are propagated to users with matching ids
  #
  def sync_student_user_from_callista(row_data)
    username_user = User.find_by(username: row_data[:username])
    student_id_user = User.find_by(student_id: row_data[:student_id])

    return username_user if username_user.present? && student_id_user.present? && username_user.id == student_id_user.id
    return nil if username_user.nil? && student_id_user.nil?

    if username_user.nil? && student_id_user.present?
      # Have with stidemt_id but not username
      student_id_user.email = row_data[:email]        # update to new emails and...
      student_id_user.username = row_data[:username]  # switch username - its the same person as the id is the same
      student_id_user.login_id = row_data[:username]  # reset to make sure not caching old data

      if student_id_user.valid?
        student_id_user.save
      else
        logger.error("Unable to fix user #{row_data} - record invalid!")
      end

      student_id_user
    elsif username_user.present? && student_id_user.nil?
      # Have with username but not student id
      username_user.student_id = row_data[:student_id] # should just need the student id

      if username_user.valid?
        username_user.save
      else
        logger.error("Unable to fix user #{row_data} - record invalid!")
      end

      username_user
    elsif username_user.present? && student_id_user.present?
      # Both present, but different
      
      logger.error("Unable to fix user #{row_data} - both username and student id users present. Need manual fix.")
      nil
    else
      logger.error("Unable to fix user #{row_data} - Need manual fix.")
      nil
    end
  end

  def find_cloud_tutorial(unit, tutorial_stats)
    if tutorial_stats.count == 1
      # There is only one... so return it!
      return tutorial_stats.first[:abbreviation]
    end

    # Sort the tutorials by fill %
    # Get the first one
    # Return its abbreviation
    list = tutorial_stats.sort_by { |r| 
      capacity = r[:capacity].present? ? r[:capacity] : 0
      capacity = 10000 if capacity <= 0
      (r[:enrolment_count] + r[:added]) / capacity
      }
    result = list.first
    result[:added] += 1
    result[:abbreviation]
  end

  # Doubtfire::Application.config.institution_settings.sync_enrolments(Unit.last)
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

          campus_name = location['name']
          campus = Campus.find_by(name: campus_name)

          if campus.nil?
            logger.error "Unable to find location #{location['name']}"
            next
          end

          is_cloud = (campus == cloud_campus)

          if is_cloud
            if unit.tutorials.where(campus_id: campus.id).count == 0
              unit.add_tutorial(
                'Asynchronous', #day
                '', #time
                'Cloud', #location
                unit.main_convenor_user, #tutor
                cloud_campus, #campus
                -1, #capacity
                default_cloud_campus_abbr, #abbrev
                nil #tutorial_stream=nil
              )                        
            end

            tutorial_stats = unit.tutorials.
              joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.tutorial_id = tutorials.id').
              where(campus_id: campus.id).
              select(
                'tutorials.abbreviation AS abbreviation',
                'capacity',
                'COUNT(tutorial_enrolments.id) AS enrolment_count'
                ).
              group('tutorials.abbreviation', 'capacity').
              map { |row|
                {
                  abbreviation: row.abbreviation,
                  enrolment_count: row.enrolment_count,
                  added: 0.0, # float to force float division in % full calc
                  capacity: row.capacity
                }
              }
          end

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
            
            # Make sure tutorials is not nil - use empty list
            tutorials = timetable_data[enrolment['studentId']]
            tutorials = [] if tutorials.nil?

            row_data = {
              unit_code:      enrolmentData['unitCode'],
              username:       enrolment['email'][/[^@]+/],
              student_id:     enrolment['studentId'],
              first_name:     enrolment['givenNames'],
              last_name:      enrolment['surname'],
              nickname:       enrolment['preferredName'],
              email:          enrolment['email'],
              enrolled:       ['ENROLLED', 'COMPLETED'].include?(enrolment['status'].upcase),
              tutorials:      tutorials,
              campus:         campus_name,
              row:            enrolment
            }

            user = sync_student_user_from_callista(row_data)

            # if they are enrolled, but not timetabled and cloud...
            if row_data[:enrolled] && timetable_data[enrolment['studentId']].nil? && is_cloud # Is this a cloud user that we have the user data for?
              # try to get their exising data
              project = unit.projects.where(user_id: user.id).first unless user.nil?
              unless project.present? && project.tutorial_enrolments.count > 0
                # not present (so new), or has no enrolment...
                tutorial = find_cloud_tutorial(unit, tutorial_stats)
                row_data[:tutorials] = [ tutorial ] unless tutorial.nil?
              end
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

  # Doubtfire::Application.config.institution_settings.fetch_timetable_data(Unit.last)
  def fetch_timetable_data(unit)
    logger.info("Fetching STAR data for #{unit.code}")

    sync_streams_from_star(unit)

    result = {}

    tp = unit.teaching_period

    url = "#{@star_url}/star-#{tp.year}/rest/students/allocated"

    unit.tutorial_streams.each do |tutorial_stream|
      logger.info("Fetching #{tutorial_stream} from #{url}")
      response = RestClient.post(url, {username: @star_user, password: @star_secret, where_clause:"subject_code LIKE '#{unit.code}%' AND activity_group_code LIKE '#{tutorial_stream.abbreviation}'"})

      if response.code == 200
        jsonData = JSON.parse(response.body)

        # Switch to the next activity type if this one is empty
        next if jsonData['allocations'].count == 0

        jsonData['allocations'].each do |allocation|
          if result[allocation['student_code'].to_i].nil?
            result[allocation['student_code'].to_i] = []
          end

          tutorial = fetch_tutorial(unit, allocation) unless allocation['student_code'].nil?
          result[allocation['student_code'].to_i] << tutorial unless tutorial.nil?
        end
      end
    end

    result
  end

  def tutorial_abbr_for_star(star_data)
    "#{star_data['campus']}-#{star_data['activity_group_code']}-#{star_data['activity_code']}"
  end

  # Returns the tutorial abbr to enrol in for this activity (one in a stream)
  def fetch_tutorial(unit, star_data)
    tutorial_code = star_data["activity_group_code"].strip() == "" ? nil : tutorial_abbr_for_star(star_data)

    unless tutorial_code.nil?
      tutorial_code = nil if unit.tutorials.where(abbreviation: tutorial_code).count == 0
    end

    tutorial_code
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

Doubtfire::Application.config.institution_settings = DeakinInstitutionSettings.new
