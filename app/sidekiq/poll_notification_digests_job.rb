# frozen_string_literal: true

class PollNotificationDigestsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['poll-notification-digests'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    # Create the 7am weekly summaries first so a digest due at the same time can include them.
    CreateWeeklySummaryNotificationsJob.new.perform

    NotificationSetting.due.find_each do |setting|
      SendNotificationDigestJob.perform_async(setting.id)
    end
  end
end
