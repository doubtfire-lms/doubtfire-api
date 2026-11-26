require 'csv'

class DownloadTutorAssessmentStatsJob
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
    logger.info "Starting tutor assessment csv download..."

    at(0)
    total(1)

    unit = Unit.find(unit_id)
    csv = unit.tutor_assessment_csv

    store(result: csv)

    logger.info "Completed tutor assessment csv download!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
