# frozen_string_literal: true

class PruneNotificationsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['prune-notifications'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    Notification
      .where.not(read_at: nil)
      .where(read_at: ...90.days.ago)
      .delete_all
  end
end
