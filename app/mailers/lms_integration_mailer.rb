# frozen_string_literal: true

class LmsIntegrationMailer < ApplicationMailer
  SYNC_NAMES = { students: 'student sync', extensions: 'extension sync' }.freeze
  SETTING_NAMES = { auto_sync_students: 'Sync students daily', auto_sync_extensions: 'Sync extensions daily' }.freeze

  def auto_sync_failed(integration, sync, error, turned_off, outage)
    @unit = integration.unit
    @convenor = @unit.main_convenor&.user
    return nil if @convenor.nil? || @convenor.email.blank?

    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @failing_since = integration.auto_sync_failing_since if outage
    @sync_name = SYNC_NAMES.fetch(sync, 'sync')
    @issues = error.respond_to?(:issues) ? error.issues : []
    @error_message = error.message
    @turned_off = turned_off.map { |setting| SETTING_NAMES[setting] }
    @lms_url = "#{@doubtfire_host}/units/#{@unit.id}/admin/lms"

    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    mail(to: convenor_email, from: convenor_email, subject: "#{@unit.code}: Daily LMS #{@sync_name} failed and has been turned off")
  end
end
