# frozen_string_literal: true

# One unit's departure from a user's notification settings. A unit with no
# preference follows the user's defaults; a preference with null channels has
# only been muted, and still follows them.
class NotificationPreference < ApplicationRecord
  include HasNotificationChannels

  belongs_to :user
  belongs_to :unit

  def customised?
    channels.present?
  end
end
