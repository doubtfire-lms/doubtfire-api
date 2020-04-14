class AuthToken < ActiveRecord::Base

  belongs_to :user

  validates :authentication_token, presence: true, uniqueness: true

  # Auth token encryption settings
  attr_encrypted :auth_token,
    key: Doubtfire::Application.secrets.secret_key_attr,
    encode: true,
    attribute: 'authentication_token'

  def self.generate(user, remember, expiry_time = Time.zone.now + 2.hours)
    # Loop until new unique auth token is found
    token = loop do
      token = Devise.friendly_token
      break token unless AuthToken.find_by_auth_token(token)
    end

    # Create a new AuthToken with this value
    result = AuthToken.new(user_id: user.id)
    result.auth_token = token
    result.extend_token(remember, expiry_time, false)
    result.save!
    result
  end

  # Find that matching token and get the associated user
  def self.user_for_token auth_token
    token = AuthToken.find_by_auth_token(auth_token)
    return nil unless token.present?
    return token.user
  end

  # Destroy all old tokens
  def self.destroy_old_tokens
    AuthToken.where("auth_token_expiry < :now", now: Time.zone.now).destroy_all
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

    if save
      self.update(auth_token_expiry: expiry_time)
    else
      self.auth_token_expiry = expiry_time
    end
  end

end
