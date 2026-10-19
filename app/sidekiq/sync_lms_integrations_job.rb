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
    outage = lti_outage

    LmsIntegration.auto_syncing.includes(:unit).find_each do |integration|
      syncs = due_syncs(integration, today, check_course_data: outage.nil?)
      next if syncs.empty?

      if outage
        integration.record_auto_sync_outage!(nil, outage)
      else
        ImportLmsStudentsJob.perform_async(integration.unit_id, false, integration.withdraw_missing_students, true) if syncs.include?(:students)
        ImportLmsExtensionsJob.perform_async(integration.unit_id, false, true) if syncs.include?(:extensions)
      end
    rescue StandardError => e
      logger.error "Failed to schedule the LMS sync for unit #{integration.unit_id}: #{e.message}"
      integration.auto_sync_failed!(nil, e)
    end
  end

  private

  # Checked once so an outage sends one email to ops instead of failing every unit's sync
  def lti_outage
    LtiServer.check_health!
    nil
  rescue LtiServer::Error => e
    logger.error "Skipping the scheduled LMS sync because the LTI service is unavailable: #{e.message}"
    email_ops(e)
    e
  end

  def email_ops(error)
    ErrorLogMailer.error_message('LMS sync skipped', 'The LTI service is unavailable, so the scheduled LMS sync was skipped.', error).deliver_now
  rescue StandardError => e
    logger.error "Failed to email the LMS sync outage: #{e.message}"
  end

  def due_syncs(integration, today, check_course_data:)
    unit = integration.unit
    return [] unless unit.active?

    syncs = []
    if integration.auto_sync_students? && today.between?(unit.start_date.to_date, unit.end_date.to_date) &&
       mappings_ready?(integration, check_course_data)
      syncs << :students
    end
    if integration.auto_sync_extensions? && integration.validated? && integration.fetch_extensions? &&
       integration.assignment_id.present? && today.between?(unit.start_date.to_date, unit.end_date.to_date + 14.days)
      syncs << :extensions
    end
    syncs
  end

  # Mappings are skipped when the plugin is unavailable, so they do not need validating
  def mappings_ready?(integration, check_course_data)
    !integration.group_mapping_enabled? || integration.validated? || (check_course_data && !course_data_available?(integration))
  end

  def course_data_available?(integration)
    integration.data_source.course_data_available?
  rescue LtiServer::Error, LtiCourseDataSource::Error
    true
  end
end
