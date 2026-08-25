# frozen_string_literal: true

class SendImmediateNotificationJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return if notification.email_processed_at.present?

    preference = NotificationPreference.for(notification.recipient, notification.unit)
    unless notification.read_at.nil? &&
           notification.unit.send_notifications &&
           !notification.recipient_withdrawn? &&
           preference.email_enabled_for?(notification.kind)
      notification.update!(email_processed_at: Time.current)
      return
    end

    sender = notification.actor || notification.unit.main_convenor_user
    if sender.nil?
      notification.update!(email_processed_at: Time.current)
      return
    end

    mail =
      if notification.kind == 'discuss_warning'
        deadline = notification.metadata['deadline']
        NotificationsMailer.discussion_deadline_approaching(
          notification.task,
          sender,
          deadline.present? ? Date.iso8601(deadline) : notification.unit.discuss_timeout_expiry_date(notification.task)
        )
      else
        NotificationsMailer.discussion_deadline_missed(notification.task, sender)
      end

    mail.deliver_now
    notification.update!(
      email_processed_at: Time.current,
      email_sent_at: Time.current
    )
  end
end
