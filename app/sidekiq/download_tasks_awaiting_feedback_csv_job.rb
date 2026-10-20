require 'csv'

class DownloadTasksAwaitingFeedbackCsvJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper

  sidekiq_options queue: 'parallel',
                  retry: false

  def perform(unit_id)
    logger.info "Starting tasks awaiting feedback csv download..."

    at(0)
    total(1)

    unit = Unit.find(unit_id)
    csv = unit.days_awaiting_feedback_by_tutorial_csv

    store(result: csv)

    logger.info "Completed tasks awaiting feedback csv download!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
