# frozen_string_literal: true

# Move old units to archive folder
class ArchiveOldUnitsJob
  include Sidekiq::Job

  def perform
    archive_period = Doubtfire::Application.config.unit_archive_after_period

    archive_period = 1.year if archive_period < 1.year

    units = Unit.where(archived: false).where('end_date < :archive_before', archive_before: DateTime.now - archive_period)

    units.find_each(&:move_files_to_archive)
  rescue StandardError => e
    begin
      # Notify system admin
      mail = ErrorLogMailer.error_message('Archive Units', "Failed to move old units to archive", e)
      mail.deliver if mail.present?

      logger.error e
    rescue StandardError => e
      logger.error "Failed to send error log to admin"
    end
  end
end
