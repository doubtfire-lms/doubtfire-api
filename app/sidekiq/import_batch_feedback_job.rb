class ImportBatchFeedbackJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { args.first(3) },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, assessor_id, task_definition_id, path_to_upload)
    logger.info "Starting batch feedback import..."

    at(0, 'Preparing batch feedback import')
    total(1)

    unit = Unit.find(unit_id)
    task_definition = unit.task_definitions.find(task_definition_id)
    assessor = User.find(assessor_id)

    file = File.open(path_to_upload, 'rb')
    result = unit.upload_batch_feedback_csv(
      assessor,
      task_definition,
      { 'tempfile' => file },
      progress_callback: lambda { |message: nil, total_rows: nil, rows_processed: nil|
        total(total_rows) if total_rows
        at(rows_processed, message) unless rows_processed.nil?
      }
    )

    store(result: result.to_json)

    logger.info "Completed batch feedback import!"
  ensure
    file&.close if defined?(file) && file.present?
    FileUtils.rm_f(path_to_upload) if path_to_upload.present?
  end
end
