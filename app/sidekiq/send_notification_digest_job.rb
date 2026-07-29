# frozen_string_literal: true

class SendNotificationDigestJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { ["notification-digest:#{args.first}"] },
                  on_conflict: :reject,
                  retry: 5

  def perform(preference_id)
    preference = NotificationPreference.find(preference_id)
    return if preference.email_frequency == 'off'

    now = Time.current
    pending = preference.user
                        .received_notifications
                        .where(unit: preference.unit)
                        .email_pending
                        .where.not(kind: Notification::DISCUSS_KINDS)
                        .includes(:recipient, :unit, task: [:task_definition, { project: :user }])
    ready_ids = pending.select { |notification| notification.email_ready?(at: now) }.map(&:id)
    ready = Notification.where(id: ready_ids)

    disabled = ready.where.not(kind: preference.email_categories)
    # These are immutable delivery-ledger updates and intentionally bypass callbacks.
    # rubocop:disable Rails/SkipsModelValidations
    disabled.update_all(email_processed_at: now, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations

    enabled = ready
              .where(kind: preference.email_categories)
              .includes(:recipient, :unit, task: [:task_definition, { project: :user }])
              .to_a
    unless preference.unit.send_notifications
      # rubocop:disable Rails/SkipsModelValidations
      Notification.where(id: enabled.map(&:id)).update_all(email_processed_at: now, updated_at: now)
      # rubocop:enable Rails/SkipsModelValidations
      preference.advance_digest!(from: now)
      return
    end

    if enabled.any?
      NotificationsMailer.notification_digest(preference, enabled).deliver_now
      # rubocop:disable Rails/SkipsModelValidations
      Notification.where(id: enabled.map(&:id)).update_all(
        email_processed_at: now,
        email_sent_at: now,
        updated_at: now
      )
      # rubocop:enable Rails/SkipsModelValidations
    end

    preference.advance_digest!(from: now)
  end
end
