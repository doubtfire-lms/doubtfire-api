# frozen_string_literal: true

class SendNotificationDigestJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { ["notification-digest:#{args.first}"] },
                  on_conflict: :reject,
                  retry: 5

  def perform(setting_id)
    setting = NotificationSetting.find(setting_id)
    return if setting.digest_frequency == 'off'

    now = Time.current
    ready = setting.user
                   .received_notifications
                   .email_pending
                   .email_ready(now)
                   .includes(:recipient, :unit, { project: :campus }, task: [:task_definition, { project: :user }])
                   .to_a
    deliverable, skipped = ready.partition { |notification| deliverable?(setting, notification) }

    mark_processed(skipped, now)
    if deliverable.any?
      NotificationsMailer.notification_digest(setting.user, deliverable).deliver_now
      mark_processed(deliverable, now, sent: true)
    end

    setting.advance_digest!(from: now)
  end

  private

  def deliverable?(setting, notification)
    notification.unit.send_notifications &&
      !notification.recipient_withdrawn? &&
      setting.delivers?(notification.unit, notification.kind, :email)
  end

  # The delivery ledger is immutable once written, so these intentionally bypass callbacks.
  def mark_processed(notifications, at, sent: false)
    return if notifications.empty?

    attributes = { email_processed_at: at, updated_at: at }
    attributes[:email_sent_at] = at if sent

    # rubocop:disable Rails/SkipsModelValidations
    Notification.where(id: notifications.map(&:id)).update_all(attributes)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
