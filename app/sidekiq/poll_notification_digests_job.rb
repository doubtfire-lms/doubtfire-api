# frozen_string_literal: true

class PollNotificationDigestsJob
  include Sidekiq::Job

  sidekiq_options queue: 'parallel',
                  lock: :until_executed,
                  lock_args_method: ->(_args) { ['poll-notification-digests'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    return if Doubtfire::Application.config.notification_emails_from.blank?

    NotificationSetting.due.find_each do |setting|
      SendNotificationDigestJob.perform_async(setting.id)
    end
  end
end
