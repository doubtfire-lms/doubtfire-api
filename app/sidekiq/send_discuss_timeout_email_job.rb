class SendDiscussTimeoutEmailJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(task_id, sender_id, notification_type, expiry_date = nil)
    task = Task.find_by(id: task_id)
    sender = User.find_by(id: sender_id)
    return if task.blank? || sender.blank?
    return unless task.unit.send_notifications

    kind = notification_type == 'approaching' ? 'discuss_warning' : 'discuss_expired'
    return unless NotificationSetting.for(task.project.student).delivers?(task.unit, kind, :email)

    mail = case notification_type
           when 'approaching'
             NotificationsMailer.discussion_deadline_approaching(task, sender, Date.iso8601(expiry_date))
           when 'missed'
             NotificationsMailer.discussion_deadline_missed(task, sender)
           else
             raise ArgumentError, "Unknown discussion deadline notification type: #{notification_type}"
           end

    mail.deliver_now
  end
end
