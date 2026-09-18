# frozen_string_literal: true

class SyncLmsIntegrationsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['sync-lms-integrations'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    return unless Doubtfire::Application.config.lti_enabled && LtiServer.configured?

    today = Time.zone.today

    LmsIntegration.includes(:unit).find_each do |integration|
      unit = integration.unit
      next unless unit.active?

      mappings_ready = !integration.group_mapping_enabled? || integration.validated?
      if integration.auto_sync_students? && mappings_ready && today.between?(unit.start_date.to_date, unit.end_date.to_date)
        ImportLmsStudentsJob.perform_async(unit.id, false, integration.withdraw_missing_students)
      end

      next unless integration.auto_sync_extensions? && integration.validated?
      next unless integration.fetch_extensions? && integration.assignment_id.present?
      next unless today.between?(unit.start_date.to_date, unit.end_date.to_date + 14.days)

      ImportLmsExtensionsJob.perform_async(unit.id, false)
    end
  end
end
