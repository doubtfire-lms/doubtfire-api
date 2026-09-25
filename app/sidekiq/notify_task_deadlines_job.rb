# frozen_string_literal: true

class NotifyTaskDeadlinesJob
  include Sidekiq::Job

  ROLLOUT_KEY = 'notifications:task_deadline:rollout_at'

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['notify-task-deadlines'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    now = Time.current
    # The first run only records the rollout time, so tasks already started, due soon or overdue are not backfilled
    started_at = rollout_started_at
    if started_at.nil?
      store_rollout_started_at(now)
      return
    end

    Notification.refresh_task_deadline_notifications!(now: now, started_at: started_at)
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
