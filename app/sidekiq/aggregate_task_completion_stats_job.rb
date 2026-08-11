# frozen_string_literal: true

class AggregateTaskCompletionStatsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id = nil)
    logger.info 'Starting task completion stats aggregation...'

    at(0)
    total(1)

    if unit_id.present?
      Unit.find(unit_id).capture_task_complete_stats_snapshot!
    else
      Unit.active_units.find_each(&:capture_task_complete_stats_snapshot!)
    end

    at(1)
    logger.info 'Completed task completion stats aggregation!'
  rescue StandardError => e
    logger.error e
    raise e
  end
end
