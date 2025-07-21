require 'csv'

class DownloadPortfoliosJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { args }
  sidekiq_options on_conflict: :reject

  sidekiq_options retry: 0

  def perform(current_user_id, unit_id)
    logger.info "Starting portfolio download..."

    at(0)
    total(0)

    unit = Unit.find(unit_id)
    current_user = User.find(current_user_id)

    output_zip = unit.get_portfolio_zip(current_user, progress_callback: lambda { |message: nil, total_rows: nil, rows_processed: nil|
      total(total_rows) if total_rows
      at(rows_processed, message) if rows_processed
    })

    store(result: File.basename(output_zip))

    logger.info "Compressed portfolio downloads!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
