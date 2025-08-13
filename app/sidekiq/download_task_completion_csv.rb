require 'csv'

class DownloadTaskCompletionCsv
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

  def perform(unit_id)
    logger.info "Starting task completion csv download..."

    at(0)
    total(1)

    unit = Unit.find(unit_id)
    csv = unit.task_completion_csv

    store(result: csv)

    logger.info "Completed task completion csv download!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
