# frozen_string_literal: true

# Shared handling of the `channels` column, which maps a notification kind to the
# channels it is delivered on: { 'new_task_comment' => ['in_app', 'email'] }.
module HasNotificationChannels
  extend ActiveSupport::Concern

  included do
    attribute :channels, :json

    validate :channels_are_known
  end

  # The channels enabled for a kind, or none when the kind is switched off.
  def channels_for(kind)
    Array(channels && channels[kind.to_s])
  end

  private

  def channels_are_known
    return if channels.nil?

    unless channels.is_a?(Hash)
      errors.add(:channels, 'must be an object')
      return
    end

    unknown_kinds = channels.keys - Notification::KINDS
    errors.add(:channels, "includes unknown kinds: #{unknown_kinds.join(', ')}") if unknown_kinds.any?

    unknown_channels = channels.values.flatten.uniq - Notification::CHANNELS
    errors.add(:channels, "includes unknown channels: #{unknown_channels.join(', ')}") if unknown_channels.any?
  end
end
