require 'csv'

class ImportStudentsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] }
  sidekiq_options retry: 0

  def perform(unit_id, path_to_csv)
    logger.info "Starting user imports..."

    at(0)

    ensure_csv!(path_to_csv)

    unit = Unit.find(unit_id)
    result = unit.import_users_from_csv(path_to_csv, progress_callback: lambda { |message: nil, total_rows: nil, rows_processed: nil|
      total(total_rows) if total_rows
      at(rows_processed, message) if rows_processed
    })

    store(result: result.to_json)

    FileUtils.rm(path_to_csv)

    logger.info "Completed user imports!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
