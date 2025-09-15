require 'csv'

class DownloadSubmissionPdfsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { args },
                  on_conflict: :reject,
                  retry: false

  def perform(current_user_id, task_definition_id, unit_id)
    logger.info "Starting submission pdfs download..."

    at(0)
    total(0)

    unit = Unit.find(unit_id)
    td = TaskDefinition.find(task_definition_id)
    current_user = User.find(current_user_id)

    output_zip = unit.get_task_submissions_pdf_zip(current_user, td, progress_callback: lambda { |message: nil, total_rows: nil, rows_processed: nil|
      total(total_rows) if total_rows
      at(rows_processed, message) if rows_processed
    })

    store(result: File.basename(output_zip))

    logger.info "Compressed submission pdfs downloads!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
