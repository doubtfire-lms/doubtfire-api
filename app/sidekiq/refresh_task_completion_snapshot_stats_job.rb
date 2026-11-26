# frozen_string_literal: true

class RefreshTaskCompletionSnapshotStatsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options queue: 'parallel',
                  lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id)
    unit = Unit.find(unit_id)
    snapshot_count = unit.task_completion_snapshots.count
    total([snapshot_count, 1].max)
    at(0)

    unit.refresh_task_completion_snapshot_stats! do |processed|
      at(processed)
    end

    at([snapshot_count, 1].max)
    store(result: 'Task completion snapshots are ready')
  end
end
