# frozen_string_literal: true

class NotifyTaskDeadlinesJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['notify-task-deadlines'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    Notification.refresh_task_deadline_notifications!
  end
end
