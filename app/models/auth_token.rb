class AuthToken < ApplicationRecord
  belongs_to :user, optional: false

  encrypts :authentication_token

  validates :authentication_token, presence: true
  validate :ensure_token_unique_for_user, on: :create

  enum token_type: {
    general: 0,
    login: 1,
    scorm: 2
  }

  def self.generate(user, remember, expiry_time = Time.zone.now + 2.hours, token_type = :general)
    # Loop until new unique auth token is found
    token = loop do
      token = Devise.friendly_token
      break token unless user.token_for_text?(token, token_type)
    end

    # Create a new AuthToken with this value
    result = AuthToken.new(user_id: user.id)
    result.authentication_token = token
    result.token_type = token_type
    result.extend_token(remember, expiry_time, false)
    result.save!
    result
  end

  # Destroy all old tokens
  def self.destroy_old_tokens
    AuthToken.where("auth_token_expiry < :now", now: Time.zone.now).destroy_all
  end

  # Destroy all tokens marked for invalidation
  def self.destroy_invalidated_tokens
    AuthToken.where("invalidation_requested_at IS NOT NULL").destroy_all
  end

  #
  # Extends an existing auth_token if needed
  #
  def extend_token(remember, expiry_time = Time.zone.now + 2.hours, save = true)
    # Extended expiry times only apply to students and convenors
    if remember
      student_expiry_time = Time.zone.now + 2.weeks
      tutor_expiry_time = Time.zone.now + 1.week
      role = user.role
      expiry_time =
        if role == Role.student || role == :student
          student_expiry_time
        elsif role == Role.tutor || role == :tutor
          tutor_expiry_time
        else
          expiry_time
        end
    end

    self.auth_token_expiry = expiry_time

    if save
      self.save
    end
  end

  # Record session binding information for a new token
  def initialize_session_binding(ip, user_agent)
    update(
      session_ip: ip,
      session_user_agent: user_agent,
      last_seen_ip: ip,
      last_seen_ua: user_agent,
      ip_history: [ip].to_json,
      last_activity_at: Time.zone.now
    )
  end

  # Return the IP history as an array
  def ip_history_array
    return [] if ip_history.nil?
    ip_history.present? ? JSON.parse(ip_history) : []
  rescue JSON::ParserError
    Rails.logger.error("Error parsing IP history for token #{id}")
    []
  end

  # Add a new IP to the history if it's not already there
  def add_ip_to_history(ip)
    history = ip_history_array
    history << ip unless history.include?(ip)
    update(ip_history: history.to_json)
  end

  # Mark this token for invalidation (will be enforced on next request)
  def invalidate
    update(invalidation_requested_at: Time.zone.now)
  end

  def ensure_token_unique_for_user
    if user.token_for_text?(authentication_token, nil)
      errors.add(:authentication_token, 'already exists for the selected user')
    end
  end
end
