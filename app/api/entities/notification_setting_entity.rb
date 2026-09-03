module Entities
  class NotificationSettingEntity < Grape::Entity
    expose :id
    expose :channels
    expose :digest_frequency
    expose :digest_interval_hours
    expose :digest_start_time
    expose :digest_time
    expose :digest_timezone do |settings, _options|
      settings.resolved_digest_timezone
    end
    expose :digest_weekday
    expose :weekly_summary
    expose :next_digest_at
    expose :last_digest_at
    expose :units, using: NotificationUnitOverrideEntity do |settings|
      settings.user.notification_unit_overrides.order(:unit_id)
    end
  end
end
