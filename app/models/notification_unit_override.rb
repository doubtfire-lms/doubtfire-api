# frozen_string_literal: true

# One unit's departure from a user's notification settings. A unit without an
# override follows those settings; an override with no channels has only been
# muted, and still follows them.
class NotificationUnitOverride < ApplicationRecord
  attribute :channels, :json

  belongs_to :user
  belongs_to :unit

  validates :channels, notification_channels: true

  def customised?
    channels.present?
  end
end
