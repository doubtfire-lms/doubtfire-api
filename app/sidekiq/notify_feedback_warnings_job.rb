# frozen_string_literal: true

class NotifyFeedbackWarningsJob
  include Sidekiq::Job

  ROLLOUT_KEY = 'notifications:feedback_warning:rollout_at'

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['notify-feedback-warnings'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    now = Time.current
    # Avoid backfilling notifications for tasks that were already overdue when this ships
    # The first run stores a one-off rollout time so we only pick up tasks that cross the threshold after started_at
    started_at = rollout_started_at
    if started_at.nil?
      store_rollout_started_at(now)
      return
    end

    Notification.refresh_feedback_warning_notifications!(now: now, started_at: started_at)
  end

  private

  def rollout_started_at
    value = Sidekiq.redis { |redis| redis.get(ROLLOUT_KEY) }
    Time.zone.parse(value) if value.present?
  end

  def store_rollout_started_at(time)
    Sidekiq.redis { |redis| redis.set(ROLLOUT_KEY, time.utc.iso8601(6), nx: true) }
  end
end
