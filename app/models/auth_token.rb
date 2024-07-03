class AuthToken < ApplicationRecord
  belongs_to :user, optional: false

  encrypts :authentication_token

  validates :authentication_token, presence: true
  validate :ensure_token_unique_for_user, on: :create

  def self.generate(user, remember, expiry_time = Time.zone.now + 2.hours, token_type = 'general')
    # Loop until new unique auth token is found
    token = loop do
      token = Devise.friendly_token
      break token unless user.token_for_text?(token)
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

  def ensure_token_unique_for_user
    if user.token_for_text?(authentication_token)
      errors.add(:authentication_token, 'already exists for the selected user')
    end
  end
end
