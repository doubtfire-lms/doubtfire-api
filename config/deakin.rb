require 'rest-client'

#
# This is an institution settings - used for custom imports of users into units.
#
class DeakinInstitutionSettings
  def logger
    Rails.logger
  end

  def initialize()
    @base_url = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_BASE_URL', nil)
    @client_id = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_CLIENT_ID', nil)
    @client_secret = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_CLIENT_SECRET', nil)

    @star_url = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_STAR_URL', nil)
    @star_user = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_STAR_USER', nil)
    @star_secret = ENV.fetch('DF_INSTITUTION_SETTINGS_SYNC_STAR_SECRET', nil)
  end

  def are_callista_headers?(headers)
    headers[0] == "person id" && headers.count == 35
  end

  def are_star_headers?(headers)
    headers.include?("student_code") && headers.count == 11
  end

  def are_headers_institution_users?(headers)
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
          missing_headers(row, ["student_code", "first_name", "last_name", "email_address", "preferred_name", "subject_code", "activity_code", "campus", "day_of_week", "start_time", "location", "campus"])
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

  def activity_type_for_group_code(activity_group_code, description)
    result = ActivityType.where('lower(abbreviation) = :abbr', abbr: activity_group_code[0...-2].downcase).first

    if result.nil?
      name = description[0...-2]
      abbr = activity_group_code[0...-2]

      result = ActivityType.create!(name: name, abbreviation: abbr)
    end

    result
  end

  def default_online_campus_abbr
    'Online-01'
  end

  # Multi code units have a stream for unit - and do not sync with star
  def setup_multi_code_streams unit
    logger.info("Setting up multi unit for #{unit.code}")

    codes = unit.code.split '/'

    stream = find_or_add_stream unit, "Cohort", "Enrolment"

    for code in codes do
      tutorial = stream.tutorials.where(abbreviation: code, campus_id: nil).first
      if tutorial.nil?
        unit.add_tutorial(
          'NA', # day
          'NA', # time
          'NA', # location
          unit.main_convenor_user, # tutor
          nil, # campus
          -1, # capacity
          code, # abbrev
          stream # tutorial_stream
        )
      end
    end
  end

  def find_or_add_stream unit, abbr, desc
    stream = unit.tutorial_streams.where(abbreviation: abbr).first

    # Create the stream ... but skip classes - unless it is in the unit's current streams
    if stream.nil? && activity_type_for_group_code(abbr, desc).abbreviation.casecmp('Cls') != 0
      stream = unit.add_tutorial_stream desc, abbr, activity_type_for_group_code(abbr, desc)
    end

    stream
  end

  # Doubtfire::Application.config.institution_settings.sync_streams_from_star(Unit.last)
  def sync_streams_from_star(unit)
    return unless unit.enable_sync_timetable

    tp = unit.teaching_period

    # url = "#{@star_url}/star-#{tp.year}/rest/activities"
    server = unit.start_date.year % 2 == 0 ? 'even' : 'odd'
    url = "#{@star_url}/#{server}/rest/activities"

    logger.info("Fetching #{unit.name} timetable from #{url}")
    response = RestClient.post(url, { username: @star_user, password: @star_secret, where_clause: "subject_code LIKE '#{unit.code}%_#{tp.period.last}'" })

    if response.code == 200
      jsonData = JSON.parse(response.body)
      if jsonData["activities"].nil?
        logger.error "Failed to sync #{unit.code} - No response from #{url}"
        return
      end

      activityData = jsonData["activities"]

      activityData.each do |activity|
        # Make sure units match
        subject_match = /.*?(?=_)/.match(activity["subject_code"])
        unit_code = subject_match.nil? ? nil : subject_match[0]
        unless unit_code == unit.code
          logger.error "Failed to sync #{unit.code} - response had unit code #{enrolmentData['unitCode']}"
          return
        end

        # Get the stream or create it...
        stream = find_or_add_stream unit, activity['activity_group_code'], activity['description']
        next if stream.nil?

        campus = Campus.find_by(abbreviation: activity['campus'])

        abbr = tutorial_abbr_for_star(activity)
        tutorial = unit.tutorials.where(abbreviation: abbr).first
        if tutorial.nil?
          unit.add_tutorial(
            activity['day_of_week'], # day
            activity['start_time'], # time
            activity['location'], # location
            unit.main_convenor_user, # tutor
            campus, # campus
            -1, # capacity
            abbr, # abbrev
            stream # tutorial_stream=nil
          )
        end
      end
    end
  end

  def fetch_star_row(row, unit)
    email_match = /(.*)(?=@)/.match(row["email_address"])
    subject_match = /.*?(?=_)/.match(row["subject_code"])
    username = email_match.nil? ? nil : email_match[0]
    unit_code = subject_match.nil? ? nil : subject_match[0]

    tutorial_code = fetch_tutorial unit, row

    {
      unit_code: unit_code,
      username: username,
      student_id: row["student_code"],
      first_name: row["first_name"],
      last_name: row["last_name"],
      nickname: row["preferred_name"] == '-' ? nil : row["preferred_name"],
      email: row["email_address"],
      enrolled: true,
      tutorials: tutorial_code.present? ? [tutorial_code] : [],
      campus: row["campus"]
    }
  end

  def map_callista_to_campus(row)
    key = row["unit mode"] == 'OFF' ? 'C' : row['unit location']
    Campus.find_by(abbreviation: key)
  end

  def online_campus
    Campus.find_by(abbreviation: 'C')
  end

  def fetch_callista_row(row, unit)
    campus = map_callista_to_campus(row)

    result = {
      unit_code: row["unit code"],
      username: row["email"],
      student_id: row["person id"],
      first_name: row["given names"],
      last_name: row["surname"],
      nickname: row["preferred given name"] == "-" ? nil : row["preferred given name"],
      email: "#{row["email"]}@deakin.edu.au",
      enrolled: row["student attempt status"] == 'ENROLLED',
      campus: campus.name,
      tutorials: []
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
      # Have with stident_id but not username
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
      # Both present, but different...
      # Most likely updated username with existing student id
      if username_user.projects.count == 0 && student_id_user.projects.count > 0
        # Change the student id user to use the new username and email
        student_id_user.username = username_user.username
        student_id_user.email = username_user.email
        student_id_user.login_id = nil
        student_id_user.auth_tokens.destroy_all

        # Correct the new username user record - so we mark this as a duplicate and move to the old record
        username_user.username = "OLD-#{username_user.username}"
        username_user.email = "DUP-#{username_user.email}"
        username_user.login_id = nil

        unless username_user.save
          logger.error("Unable to fix user #{row_data} - username_user.save failed")
          return nil
        end
        username_user.auth_tokens.destroy_all

        unless student_id_user.save
          logger.error("Unable to fix user #{row_data} - student_id_user.save failed")
          return nil
        end

        # We keep the student id user... so return this
        student_id_user
      else
        logger.error("Unable to fix user #{row_data} - both username and student id users present. Need manual fix.")
        nil
      end
    else
      logger.error("Unable to fix user #{row_data} - Need manual fix.")
      nil
    end
  end

  def find_online_tutorial(unit, tutorial_stats)
    if tutorial_stats.count == 1
      # There is only one... so return it!
      return tutorial_stats.first[:abbreviation]
    end

    # Sort the tutorials by fill %
    # Get the first one
    # Return its abbreviation
    list = tutorial_stats.sort_by { |r|
      capacity = r[:capacity].presence || 0
      capacity = 10000 if capacity <= 0
      (r[:enrolment_count] + r[:added]) / capacity
    }
    result = list.first
    result[:added] += 1
    result[:abbreviation]
  end

  # Doubtfire::Application.config.institution_settings.sync_enrolments(Unit.last)
  def sync_enrolments(unit)
    return unless unit.enable_sync_enrolments

    logger.info("Starting sync for #{unit.code}")
    result = {
      success: [],
      ignored: [],
      errors: []
    }

    tp = unit.teaching_period

    # in this process we need to keep track of those students already enrolled for
    # cases where multi-unit enrolments "enrol" a user in unit 1 and "withdraw" them in unit 2
    # this will keep a list of the enrolled students from earlier units to ensure they are not
    # subsequently withdrawn
    already_enrolled = {}

    if tp.blank?
      logger.error "Failing to sync unit #{unit.code} as not in teaching period"
      return
    end

    begin
      codes = unit.code.split('/')
      multi_unit = codes.length > 1

      if multi_unit
        setup_multi_code_streams(unit)
        timetable_data = {}
      end

      for code in codes do
        # Get URL to enrolment data for this code
        url = "#{@base_url}?academicYear=#{tp.year}&periodType=trimester&period=#{tp.period.last}&unitCode=#{code}"
        logger.info("Requesting #{url}")

        # Get json from enrolment server
        response = RestClient.get(url, headers = { "client_id" => @client_id, "client_secret" => @client_secret })

        # Check we get a valid response
        if response.code == 200
          jsonData = JSON.parse(response.body)
          if jsonData["unitEnrolments"].nil?
            logger.error "Failed to sync #{code} - No response from #{url}"
            next
          end

          enrolmentData = jsonData["unitEnrolments"].first
          # Make sure units match
          unless enrolmentData['unitCode'] == code
            logger.error "Failed to sync #{code} - response had unit code #{enrolmentData['unitCode']}"
            next
          end

          # Make sure correct trimester
          unless enrolmentData['teachingPeriod']['year'].to_i == tp.year && "#{enrolmentData['teachingPeriod']['type'][0].upcase}#{enrolmentData['teachingPeriod']['period']}" == tp.period
            logger.error "Failed to sync #{code} - response had trimester #{enrolmentData['teachingPeriod']}"
            next
          end

          logger.info "Syncing enrolment for #{code} - #{tp.year} #{tp.period}"

          # Get the list of students
          student_list = []

          # Get the timetable data ()
          if multi_unit
            # We just enrol people in a "tutorial" associated with the unit code
            tutorials = [code]
          else
            # Get timetable data for students - unless it is multi-unit... cant sync those timetables ATM
            timetable_data = fetch_timetable_data(unit)
          end

          # For each location in the enrolment data...
          enrolmentData['locations'].each do |location|
            logger.info " - Syncing #{location['name']}"

            # Get campus
            campus_name = location['name']
            campus = Campus.find_by(name: campus_name)

            if campus.nil?
              logger.error "Unable to find location #{location['name']}"
              next
            end

            is_online = (campus == online_campus)

            # Online tutorials are allocated to the tutorial with the smallest pct full
            # We need to determine the stats here before the enrolments.
            # This is not needed for multi unit as we do not setup the tutorials for multi units

            if is_online && !multi_unit && unit.enable_sync_timetable
              if unit.tutorials.where(campus_id: campus.id).count == 0
                unit.add_tutorial(
                  'Asynchronous', # day
                  '', # time
                  'Online', # location
                  unit.main_convenor_user, # tutor
                  online_campus, # campus
                  -1, # capacity
                  default_online_campus_abbr, # abbrev
                  nil # tutorial_stream=nil
                )
              end

              # Get stats for distribution of students across tutorials - for enrolment of online students
              tutorial_stats = unit.tutorials
                                   .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.tutorial_id = tutorials.id')
                                   .where(campus_id: campus.id)
                                   .select(
                                     'tutorials.abbreviation AS abbreviation',
                                     'capacity',
                                     'COUNT(tutorial_enrolments.id) AS enrolment_count'
                                   )
                                   .group('tutorials.abbreviation', 'capacity')
                                   .map { |row|
                {
                  abbreviation: row.abbreviation,
                  enrolment_count: row.enrolment_count,
                  added: 0.0, # float to force float division in % full calc
                  capacity: row.capacity
                }
              }
            end # is online

            # For each of the enrolments...
            location['enrolments'].each do |enrolment|
              # Skip enrolments without an email
              if enrolment['email'].nil?
                # Only error if they were enrolled
                if ['ENROLLED', 'COMPLETED'].include?(enrolment['status'].upcase)
                  result[:errors] << { row: enrolment, message: 'Missing email and username!' }
                else
                  result[:ignored] << { row: enrolment, message: 'Not enrolled, but no email/username' }
                end

                next
              end

              # Get the list of tutorials for the student
              unless multi_unit || !unit.enable_sync_timetable
                tutorials = timetable_data[enrolment['studentId']]
                # multi unit tutorials is already setup with the unit code
              end

              # Record the data associated with the student record
              row_data = {
                unit_code: enrolmentData['unitCode'],
                username: enrolment['email'][/[^@]+/],
                student_id: enrolment['studentId'],
                first_name: enrolment['givenNames'],
                last_name: enrolment['surname'],
                nickname: enrolment['preferredName'],
                email: enrolment['email'],
                enrolled: ['ENROLLED', 'COMPLETED'].include?(enrolment['status'].upcase),
                tutorials: tutorials || [], # tutorials unless they are not present
                campus: campus_name,
                row: enrolment
              }

              logger.debug(row_data)

              # Record details for students already enrolled to work with multi-units
              if row_data[:enrolled]
                already_enrolled[row_data[:username]] = true
              elsif already_enrolled[row_data[:username]]
                # skip to the next enrolment... this person was enrolled in an earlier unit nested within this unit... so skip this row as it would result in withdrawal
                next
              end

              user = sync_student_user_from_callista(row_data)

              # if they are enrolled, but not timetabled and online...
              if is_online && row_data[:enrolled] && !multi_unit && unit.enable_sync_timetable && timetable_data[enrolment['studentId']].nil? # Is this an online user that we have the user data for?
                # try to get their exising data
                project = unit.projects.where(user_id: user.id).first unless user.nil?

                if project.nil? || project.tutorial_enrolments.count == 0
                  # not present (so new), or has no enrolment... so we can enrol it into the online tutorial
                  tutorial = find_online_tutorial(unit, tutorial_stats)
                  row_data[:tutorials] = [tutorial] unless tutorial.nil?
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
        end # if response 200
      end # for each code
    rescue Exception => e
      logger.error "Failed to sync unit: #{e.message}"
    end
    result
  end

  # Doubtfire::Application.config.institution_settings.fetch_timetable_data(Unit.last)
  def fetch_timetable_data(unit)
    return {} unless unit.enable_sync_timetable

    logger.info("Fetching STAR data for #{unit.code}")

    sync_streams_from_star(unit)

    result = {}

    tp = unit.teaching_period

    # url = "#{@star_url}/star-#{tp.year}/rest/students/allocated"
    server = unit.start_date.year % 2 == 0 ? 'even' : 'odd'
    url = "#{@star_url}/#{server}/rest/students/allocated"

    unit.tutorial_streams.each do |tutorial_stream|
      logger.info("Fetching #{tutorial_stream.abbreviation} from #{url}")
      response = RestClient.post(url, { username: @star_user, password: @star_secret, where_clause: "subject_code LIKE '#{unit.code}%' AND activity_group_code LIKE '#{tutorial_stream.abbreviation}'" })

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
