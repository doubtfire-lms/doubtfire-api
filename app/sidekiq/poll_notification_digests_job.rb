# frozen_string_literal: true

class PollNotificationDigestsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['poll-notification-digests'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    NotificationPreference.due.find_each do |preference|
      SendNotificationDigestJob.perform_async(preference.id)
    end
  end
end
