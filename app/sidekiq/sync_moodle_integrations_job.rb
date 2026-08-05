# frozen_string_literal: true

class SyncMoodleIntegrationsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['sync-moodle-integrations'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    today = Time.zone.today

    MoodleIntegration.includes(:unit).find_each do |integration|
      unit = integration.unit
      next unless unit.moodle_enabled? && unit.active?

      if integration.auto_sync_students? && today.between?(unit.start_date.to_date, unit.end_date.to_date)
        ImportMoodleStudentsJob.perform_async(unit.id, false)
      end

      next unless integration.auto_sync_extensions?
      next unless integration.fetch_extensions? && integration.assignment_id.present?
      next unless today.between?(unit.start_date.to_date, unit.end_date.to_date + 14.days)

      ImportMoodleExtensionsJob.perform_async(unit.id, false)
    end
  end
end
