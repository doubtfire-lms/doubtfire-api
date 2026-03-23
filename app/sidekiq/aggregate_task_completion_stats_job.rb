# frozen_string_literal: true

class AggregateTaskCompletionStatsJob
  include Sidekiq::Job

  def perform(unit_id = nil)
    if unit_id.present?
      Unit.find(unit_id).capture_task_complete_stats_snapshot!
      return
    end

    Unit.active_units.find_each(&:capture_task_complete_stats_snapshot!)
  end
end
