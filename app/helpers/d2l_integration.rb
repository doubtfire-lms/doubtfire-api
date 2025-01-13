# frozen_string_literal: true

require 'oauth2'

# Class to load d2l integration features
#
class D2lIntegration
  def self.enabled?
    Doubtfire::Application.config.d2l_enabled &&
      Doubtfire::Application.config.d2l_client_id.present? &&
      Doubtfire::Application.config.d2l_client_secret.present? &&
      Doubtfire::Application.config.d2l_redirect_uri.present?
  end

  def self.d2l_client_id
    Doubtfire::Application.config.d2l_client_id
  end

  def self.d2l_client_secret
    Doubtfire::Application.config.d2l_client_secret
  end

  def self.d2l_redirect_uri
    Doubtfire::Application.config.d2l_redirect_uri
  end

  def self.d2l_oauth_site
    Doubtfire::Application.config.d2l_oauth_site
  end

  def self.d2l_oauth_authorize_url
    Doubtfire::Application.config.d2l_oauth_authorize_url
  end

  def self.d2l_oauth_token_url
    Doubtfire::Application.config.d2l_oauth_token_url
  end

  def self.d2l_api_version
    Doubtfire::Application.config.d2l_api_version
  end

  def self.d2l_api_host
    Doubtfire::Application.config.d2l_api_host
  end

  def self.load_config(config)
    config.d2l_enabled = ENV['D2L_ENABLED'].present? && (ENV['D2L_ENABLED'].to_s.downcase == 'true' || ENV['D2L_ENABLED'].to_i == 1)

    if config.d2l_enabled
      config.d2l_client_id = ENV.fetch('D2L_CLIENT_ID', nil)
      config.d2l_client_secret = ENV.fetch('D2L_CLIENT_SECRET', nil)
      config.d2l_redirect_uri = ENV.fetch('D2L_REDIRECT_URI', nil)
      config.d2l_oauth_site = ENV.fetch('D2L_OAUTH_SITE', nil)
      config.d2l_oauth_authorize_url = ENV.fetch('D2L_OAUTH_SITE_AUTHORIZE_URL', nil)
      config.d2l_oauth_token_url = ENV.fetch('D2L_OAUTH_SITE_TOKEN_URL', nil)
      config.d2l_api_host = ENV.fetch('D2L_API_HOST', nil)
      config.d2l_api_version = ENV.fetch('D2L_API_VERSION', nil)
    end
  end

  def self.oauth_client
    return nil unless self.enabled?

    OAuth2::Client.new(
      self.d2l_client_id,
      self.d2l_client_secret,
      site: self.d2l_oauth_site,
      authorize_url: self.d2l_oauth_authorize_url,
      token_url: self.d2l_oauth_token_url
    )
  end

  def self.login_url(user)
    return nil unless self.enabled?

    # Create oauth client to initiate login
    client = self.oauth_client

    # Generate a random state, unique within the user_oauth_states table
    state = SecureRandom.hex(16)

    # Ensure state is unique
    i = 0
    state = SecureRandom.hex(16) until UserOauthState.create(state: state, user: user) || ++i > 5

    if UserOauthState.find_by(state: state, user: user).nil?
      raise 'Could not create unique state'
    end

    # Generate login url
    client.auth_code.authorize_url(redirect_uri: self.d2l_redirect_uri, 'scope' => 'core:*:* enrollment:orgunit:read grades:*:*', 'state' => state)
  end

  def self.process_callback(code, state)
    client = self.oauth_client

    begin
      # Get the access token
      access_token = client.auth_code.get_token(
        code,
        redirect_uri: self.d2l_redirect_uri
      )
    rescue OAuth2::Error => e
      Rails.logger.error("Error getting oauth access token: #{e.message}")
      raise(StandardError, 'Error getting access token')
    end

    # Extract the token needed to be stored
    token = access_token.token

    # Find the state in the user_oauth_states table
    user_oauth_state = UserOauthState.find_by(state: state)

    raise(StandardError, 'Invalid state') if user_oauth_state.nil?

    Rails.logger.info("User #{user_oauth_state.user.id} logged in with D2L")

    # Create a user oauth token
    UserOauthToken.create(
      user: user_oauth_state.user,
      provider: :d2l,
      token: token,
      expires_at: Time.zone.now + 30.minutes
    )

    user_oauth_state.destroy
  end

  def self.test_has_details_for!(unit, user)
    raise(StandardError, 'D2L not enabled') unless self.enabled?

    # Find the D2L assessment mapping
    d2l_mapping = unit.d2l_assessment_mapping
    raise(StandardError, 'Add the org unit id in unit administration before posting grades') if d2l_mapping.nil?

    # Get the user's oauth token
    token = user.user_oauth_tokens.find_by(provider: :d2l)

    raise(StandardError, `No D2L token found for user #{user.username} when accessing unit #{unit.code}`) if token.nil?
  end

  def self.grades_url(d2l_mapping)
    "#{D2lIntegration.d2l_api_host}/d2l/api/le/#{D2lIntegration.d2l_api_version}/#{d2l_mapping.org_unit_id}/grades/#{d2l_mapping.grade_object_id}"
  end

  def self.does_grade_item_exist?(d2l_mapping, access_token)
    return false if d2l_mapping.grade_object_id.nil?

    url = self.grades_url(d2l_mapping)

    # Call D2L API to check if the grade item exists
    begin
      # Try to get the grade item, and if this succeeds, the grade item exists
      response = access_token.get(url)
      return false unless response.present? && response.status == 200
      response.parsed.id == d2l_mapping.grade_object_id
    rescue OAuth2::Error => e
      Rails.logger.error("Error checking grade item: #{e.message}")
      d2l_mapping.grade_object_id = nil
      d2l_mapping.save
      false
    end
  end

  def self.create_grade_item(d2l_mapping, access_token)
    return if self.does_grade_item_exist?(d2l_mapping, access_token)

    app_name = Doubtfire::Application.config.institution[:product_name]

    # Create a grade item in D2L
    url = self.grades_url(d2l_mapping)
    begin
      response = access_token.post(
        url,
        body: {
          'MaxPoints' => 100,
          'CanExceedMaxPoints' => false,
          'IsBonus' => false,
          'ExcludeFromFinalGradeCalculation' => false,
          'GradeSchemeId' => nil,
          'Name' => "#{app_name} Result",
          'ShortName' => 'Result',
          'GradeType' => 'Numeric',
          'CategoryId' => nil,
          'Description' => {
            'Content' => "Result from #{app_name}",
            'Type' => 'Text'
          },
          'AssociatedTool' => nil,
          'IsHidden' => true
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      d2l_mapping.grade_object_id = response.parsed.id
      d2l_mapping.save
    rescue OAuth2::Error => e
      Rails.logger.error("Error creating grade item: #{e.response.status} #{e.response.body}")
      raise(StandardError, 'Error creating grade item')
    end
  end

  def self.get_grade_weight(d2l_mapping, access_token)
    url = "#{D2lIntegration.d2l_api_host}/d2l/api/le/#{D2lIntegration.d2l_api_version}/#{d2l_mapping.org_unit_id}/grades/categories/"

    begin
      response = access_token.get(url)
      response.parsed
    rescue OAuth2::Error => e
      Rails.logger.error("Error getting grade weight: #{e.message}")
      raise(StandardError, 'Error getting grade weight')
    end
  end

  def self.get_class_list(d2l_mapping, access_token)
    url = "#{D2lIntegration.d2l_api_host}/d2l/api/le/#{D2lIntegration.d2l_api_version}/#{d2l_mapping.org_unit_id}/classlist/"

    begin
      response = access_token.get(url)
      response.parsed
    rescue OAuth2::Error => e
      Rails.logger.error("Error getting class list: #{e.message}")
      raise(StandardError, "Error getting class list")
    end
  end

  def self.find_project_for_d2l_user(unit, d2l_user)
    # Find using the user's org defined id
    unit.projects.joins(:user).find_by(users: { student_id: d2l_user['OrgDefinedId'] }) ||
      # Find using the user's username
      unit.projects.joins(:user).find_by(users: { username: d2l_user['UserName'] }) ||
      # Find using the user's email
      unit.projects.joins(:user).find_by(users: { email: d2l_user['Email'] })
  end

  def self.access_token_for_user(user)
    oauth_token = user.user_oauth_tokens.where(provider: :d2l).last
    if oauth_token.present?
      oauth_token.access_token
    else
      oauth_token # Return nil
    end
  end

  def self.access_token_for_user!(user)
    token = D2lIntegration.access_token_for_user(user)
    if token.nil?
      raise(StandardError, 'No D2L token found for user')
    end

    token
  end

  def self.post_grades(unit, user)
    test_has_details_for!(unit, user)

    app_name = Doubtfire::Application.config.institution[:product_name]

    # Get the D2L assessment mapping
    d2l_mapping = unit.d2l_assessment_mapping

    token = D2lIntegration.access_token_for_user!(user)

    # Check if we need to create the grade item
    unless self.does_grade_item_exist?(d2l_mapping, token)
      create_grade_item(d2l_mapping, token)
    end

    # Get the class list
    list = self.get_class_list(d2l_mapping, token)

    result = []
    done = []

    list.each do |d2l_student|
      if d2l_student['ClasslistRoleDisplayName'] != 'Student'
        result << "Ignored,#{d2l_student['OrgDefinedId']},,\"#{d2l_student['DisplayName']} is not a student\""
        next
      end

      project = self.find_project_for_d2l_user(unit, d2l_student)
      if project.nil?
        result << "Not Found in #{app_name},#{d2l_student['OrgDefinedId']},,\"No #{app_name} details for #{d2l_student['DisplayName']} found from D2L\""
        next
      end

      done << project.id

      # Get the grade for the project
      if project.grade.nil? || project.grade <= 0
        result << "Skipped,#{d2l_student['OrgDefinedId']},,\"No grade for #{project.student.username} in #{app_name}\""
        next
      end

      url = "#{D2lIntegration.d2l_api_host}/d2l/api/le/#{D2lIntegration.d2l_api_version}/#{d2l_mapping.org_unit_id}/grades/#{d2l_mapping.grade_object_id}/values/#{d2l_student['Identifier']}"

      # Post the grade to D2L
      begin
        response = token.put(
          url,
          body: {
            "GradeObjectType" => 1,
            "PointsNumerator" => project.grade
          }.to_json
        )

        # Check if we need to sleep for rate limiting
        if response.headers['X-Rate-Limit-Remaining'].present? && response.headers['X-Request-Cost'].present? && response.headers['X-Rate-Limit-Remaining'].to_i < ((response.headers['X-Request-Cost'].to_i * 3) || 10)
          sleep(response.headers['X-Rate-Limit-Reset'].to_i)
        end

        result << "Success,#{d2l_student['OrgDefinedId']},#{project.grade},\"Posted grade for #{project.student.username}\""
      rescue OAuth2::Error => e
        Rails.logger.error("Error posting grade for #{unit.code} #{project.student.username}: #{e.response.status} #{e.response.body}")
        result << "Failed,#{d2l_student['OrgDefinedId']},#{project.grade},\"Error posting grade for #{d2l_student['DisplayName']}\""
      end
    end

    # Report students not found in the class list
    unit.active_projects.each do |project|
      unless done.include?(project.id)
        result << "Not Found,#{project.user.username},#{project.grade},Not found in D2L list"
      end
    end

    result
  end

  def self.result_file_path(unit)
    "#{FileHelper.unit_dir(unit)}/d2l_post_grades_job_result.csv"
  end

  def self.d2l_grade_job_present?(unit)
    queue = Sidekiq::Queue.new("default")
    queue.each do |job|
      return true if job.klass == 'D2lPostGradesJob' && job.args[0] == unit.id
    end

    Sidekiq::Workers.new.map do |_process_id, _thread_id, work|
      payload = JSON.parse(work['payload'])

      return true if payload['class'] == 'D2lPostGradesJob' && payload['args'][0] == unit.id
    end

    false
  end

  def self.grade_weighted?(d2l_mapping, user)
    url = "#{D2lIntegration.d2l_api_host}/d2l/api/le/#{D2lIntegration.d2l_api_version}/#{d2l_mapping.org_unit_id}/grades/setup/"

    access_token = D2lIntegration.access_token_for_user(user)

    return false if access_token.nil?

    begin
      response = access_token.get(url)
      'Weighted'.casecmp(response.parsed['GradingSystem'])
    rescue OAuth2::Error => e
      Rails.logger.error("Error getting class list: #{e.message}")
      false
    end
  end
end
