require 'csv'

class DownloadOverflowTaskClaimsCsvJob
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
    logger.info "Starting overflow task claims csv download..."

    at(0)
    total(1)

    unit = Unit.find(unit_id)
    csv = unit.overflow_task_claims_csv

    store(result: csv)

    logger.info "Completed overflow task claims csv download!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
