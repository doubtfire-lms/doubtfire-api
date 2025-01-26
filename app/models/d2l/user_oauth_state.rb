# frozen_string_literal: true

class UserOauthState < ApplicationRecord
  belongs_to :user

  # Ensure unique states
  validates :state, uniqueness: true

  def self.destroy_old_states
    UserOauthState.where('created_at < ?', Time.zone.now - 15.minutes).delete_all
  end
end
