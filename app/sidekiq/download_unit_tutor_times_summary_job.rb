require 'csv'

class DownloadUnitTutorTimesSummaryJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, start_date, end_date, ignore_sessions_during_tutorials)
    start_date = Date.parse(start_date) if start_date
    end_date   = Date.parse(end_date) if end_date
    logger.info "Starting unit tutor times summary csv download..."

    at(0)
    total(1)

    unit = Unit.find(unit_id)
    csv = unit.get_tutor_times_csv(start_date: start_date, end_date: end_date, ignore_sessions_during_tutorials: ignore_sessions_during_tutorials)

    store(result: csv)

    logger.info "Completed unit tutor times summary csv download!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
