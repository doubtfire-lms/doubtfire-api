# frozen_string_literal: true

class SendImmediateNotificationJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return if notification.email_processed_at.present?

    settings = NotificationSetting.for(notification.recipient)
    unless notification.read_at.nil? &&
           notification.unit.send_notifications &&
           !notification.recipient_withdrawn? &&
           settings.delivers?(notification.unit, notification.kind, :email)
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
        NotificationsMailer.discussion_deadline_approaching(
          notification.task,
          sender,
          notification.discuss_deadline || notification.unit.discuss_timeout_expiry_date(notification.task)
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
