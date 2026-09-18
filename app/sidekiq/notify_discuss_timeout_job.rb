class NotifyDiscussTimeoutJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['notify-discuss-timeout'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    Unit.notify_discuss_timeouts!
  end
end
