module Entities
  class NotificationSettingEntity < Grape::Entity
    expose :id
    expose :channels
    expose :digest_frequency
    expose :digest_interval_hours
    expose :digest_start_time
    expose :digest_end_time
    expose :digest_time
    expose :digest_timezone do |settings, _options|
      settings.resolved_digest_timezone
    end
    expose :digest_weekday
    expose :next_digest_at
    expose :last_digest_at
    expose :units, using: NotificationUnitOverrideEntity do |settings|
      settings.user.notification_unit_overrides.order(:unit_id)
    end
    # The user's units that never email, so their email choices can be shown as unavailable.
    expose :email_disabled_unit_ids do |settings, _options|
      user = settings.user
      Unit.where(send_notifications: false)
          .where(id: user.projects.select(:unit_id))
          .or(Unit.where(send_notifications: false).where(id: user.unit_roles.select(:unit_id)))
          .pluck(:id)
    end
  end
end
