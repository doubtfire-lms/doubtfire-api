# frozen_string_literal: true

# Checks the `channels` column, which maps a notification kind to the channels it
# is delivered on: { 'new_task_comment' => ['in_app', 'email'] }.
class NotificationChannelsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?

    unless value.is_a?(Hash)
      record.errors.add(attribute, 'must be an object')
      return
    end

    unknown_kinds = value.keys - Notification::KINDS
    record.errors.add(attribute, "includes unknown kinds: #{unknown_kinds.join(', ')}") if unknown_kinds.any?

    unknown_channels = value.values.flatten.uniq - Notification::CHANNELS
    record.errors.add(attribute, "includes unknown channels: #{unknown_channels.join(', ')}") if unknown_channels.any?
  end
end
