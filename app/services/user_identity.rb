# frozen_string_literal: true

#
# Finds OnTrack users by their institution login id, then username, then email. SAML sign in,
# LTI launches and LMS imports all share this lookup so a person always resolves to the same account.
#
module UserIdentity
  module_function

  def user_id_data(login_id:, email:)
    {
      login_id: login_id.presence,
      email: email,
      username: email.to_s[/(.*)@/, 1]
    }
  end

  # Institution settings decide which LTI member field holds the institution login id
  def lti_user_id_data(member)
    settings = Doubtfire::Application.config.institution_settings
    return settings.map_lti_member_to_user_id(member) if settings.respond_to?(:map_lti_member_to_user_id)

    user_id_data(login_id: member['ext_user_username'].presence || member['user_id'], email: member['email'])
  end

  # Institution settings can reject login ids that are not institution ids, such as old LMS user ids
  def institution_login_id(login_id)
    return nil if login_id.blank?

    settings = Doubtfire::Application.config.institution_settings
    return login_id unless settings.respond_to?(:institution_login_id?)

    settings.institution_login_id?(login_id) ? login_id : nil
  end

  def find_user(login_id:, email:, username: nil)
    login_id = institution_login_id(login_id)
    username ||= email.to_s[/(.*)@/, 1]
    (login_id.present? && User.find_by(login_id: login_id)) ||
      (username.present? && User.find_by(username: username)) ||
      (email.present? && User.find_by(email: email)) ||
      nil
  end

  # True when the account already belongs to a different institution login id
  def mismatch?(user, login_id)
    incoming = institution_login_id(login_id)
    stored = institution_login_id(user.login_id)
    incoming.present? && stored.present? && !stored.casecmp?(incoming)
  end

  # Logs a matched account that belongs to a different login id, and returns true when
  # DF_ENFORCE_LOGIN_ID_MATCH says it must not be used. Also logs a changed email, which may need a
  # manual username change.
  def blocked?(user, login_id:, email:, source:)
    if mismatch?(user, login_id)
      log_identity_event('login_id_mismatch', user, login_id: login_id, email: email, source: source)
      return Doubtfire::Application.config.enforce_login_id_match
    end

    if email.present? && user.email.present? && !user.email.casecmp?(email)
      log_identity_event('login_id_email_changed', user, login_id: login_id, email: email, source: source)
    end
    alert_username_changed(user, login_id: login_id, email: email, source: source) if username_changed?(user, login_id, email)
    false
  end

  # Same person by login id, but their email now derives a different username
  def username_changed?(user, login_id, email)
    incoming = institution_login_id(login_id)
    username = email.to_s[/(.*)@/, 1]
    incoming.present? && user.login_id.to_s.casecmp?(incoming) &&
      username.present? && user.username.present? && !user.username.casecmp?(username)
  end

  # Emails the details to the error address and sends Sentry a message without user details, once a day per change
  def alert_username_changed(user, login_id:, email:, source:)
    username = email.to_s[/(.*)@/, 1]
    return unless Rails.cache.write("user_identity/username_changed/#{user.id}/#{username.downcase}", true, expires_in: 1.day, unless_exist: true)

    Sentry.capture_message('User matched by login id has a changed username', level: :warning, extra: { source: source }) if defined?(Sentry)

    message = "User #{user.id} (#{user.username}) matched login id #{login_id} during #{source}, " \
              "but their email #{email} now gives the username #{username}. The username may need to be changed manually."
    ErrorLogMailer.error_message('Username changed', message, StandardError.new(message))&.deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send username change alert for user #{user.id}: #{e.message}"
  end

  # Fills in a missing login id or username on a matched account, never replacing either. A stored
  # login id the institution does not recognise counts as missing.
  def link_identity(user, login_id:, username: nil)
    return false if user.new_record?

    login_id = institution_login_id(login_id)
    missing = {}
    missing[:login_id] = login_id if login_id && institution_login_id(user.login_id).nil?
    missing[:username] = username if username.present? && user.username.blank?
    missing.any? && user.update(missing)
  rescue ActiveRecord::RecordNotUnique
    log_identity_event('login_id_taken', user, login_id: login_id, email: nil, source: 'link')
    false
  end

  def log_identity_event(event, user, login_id:, email:, source:)
    Rails.logger.warn({
      event: event,
      source: source,
      user_id: user.id,
      username: user.username,
      stored_login_id: user.login_id,
      incoming_login_id: login_id,
      stored_email: user.email,
      incoming_email: email
    }.to_json)
  end
end
