class JplagSimilarityJob
  include Sidekiq::Job
  include LogHelper

  sidekiq_options queue: :jplag,
                  lock: :until_and_while_executing,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject
  # use `retry: false` to execute this once and only once
  # use `retry: 0` to send the job to the dead queue
  # We can then look at the dead queue and identify the task ID and user ID
  # retry: 0

  # TODO:  errors should clear the in_process files
  # TODO: this job itself should handle the moving of files
  def perform(task_def_id)
    begin
      # Ensure cwd is valid...
      FileUtils.cd(Rails.root)
    rescue StandardError => e
      logger.error e
      raise "cwd is invalid"
    end

    # unit = Unit.find(unit_id)
    td = TaskDefinition.find(task_def_id)
    unit = td.unit

    tasks = unit.tasks_for_definition(td)

    processing = tasks.select(&:processing_pdf?)
    if processing.any?
      # We can raise errors which will force Sidekiq to retry this job later
      raise "Some tasks are still processing PDFs: Task IDs: [#{processing.map(&:id).join(', ')}]"
    end

    tasks_with_files = tasks.select(&:has_pdf)

    unit_code = "#{unit.code}-#{unit.id}"

    # TODO: jplag_move_files_job
    # - If this one fails, we can retry
    # TODO: jplag_run_job

    begin
      root_work_dir = Rails.root.join("tmp", "jplag", "#{unit.code}-#{unit.id}")
      tasks_dir = "#{root_work_dir}-#{Process.pid}-#{Thread.current.object_id}-#{Time.now.to_i}-#{td.id}"
      FileUtils.mkdir_p(tasks_dir)
      unit.run_jplag_on_done_files(td, tasks_dir, tasks_with_files, unit_code)

      # run_jplag_on_done_files(td, tasks_dir, tasks_with_files, unit_code)
      report_path = "#{Doubtfire::Application.config.jplag_report_dir}/#{unit_code}/#{td.abbreviation}-result.jplag"
      warn_pct = td.plagiarism_warn_pct || 50
      logger.debug "Warn PCT: #{warn_pct}"
      unit.process_jplag_plagiarism_report(report_path, warn_pct, td.group_set)
    rescue StandardError => e
      logger.error e

      # begin
      #   # Notify system admin
      #   mail = ErrorLogMailer.error_message('JPlag Similarity', "Failed to convert submission to PDF for task #{task.log_details}", e)
      #   mail.deliver if mail.present?
      # rescue StandardError => e
      #   logger.error "Failed to send error log to admin"
      # end
      raise "#{e} - JPlag failed on unit"
    end
  rescue StandardError => e # to raise error message to avoid unnecessary retry
    logger.error e
    raise e
  end
end
