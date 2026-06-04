require_all 'lib/helpers'
require 'sidekiq/api'

namespace :maintenance do
  def accept_submission_job_present?(task_id)
    Sidekiq::Queue.new("default").each do |job|
      return true if job.klass == 'AcceptSubmissionJob' && job.args[0] == task_id
    end

    Sidekiq::Workers.new.each do |_process_id, _thread_id, work|
      payload = JSON.parse(work['payload'])

      return true if payload['class'] == 'AcceptSubmissionJob' && payload['args'][0] == task_id
    end

    false
  end

  def notify_failed_submission(task, message)
    if task.project.student.receive_task_notifications
      begin
        PortfolioEvidenceMailer.task_pdf_failed(task.project, [task]).deliver_now
      rescue StandardError => e
        Rails.logger.error "Failed to send task pdf failed email for project #{task.project.id}!\n#{e.message}"
      end
    end

    exception = StandardError.new(message)
    Sentry.capture_exception(exception, extra: { task_id: task.id, project_id: task.project_id }) if defined?(Sentry)

    begin
      mail = ErrorLogMailer.error_message('Accept Submission Cleanup', message, exception)
      mail.deliver_now if mail.present?
    rescue StandardError => e
      Rails.logger.error "Failed to send error log to admin for task #{task.id}!\n#{e.message}"
    end
  end

  def mark_task_for_resubmission(task, _message)
    tutor = task.project.tutor_for(task.task_definition)

    task.trigger_transition(trigger: 'fix', by_user: tutor)
    task.add_text_comment(tutor, "**Automated Comment**: Something went wrong with compiling your submission. Please resubmit the task.")
  rescue StandardError => e
    Rails.logger.error "Failed to move task #{task.id} to fix and add automated comment!\n#{e.message}"
  end

  def clear_abandoned_submissions!
    in_process_path = FileHelper.student_work_dir(:in_process)
    return unless Dir.exist?(in_process_path)

    abandoned_submission_timeout = 10.minutes
    stale_before = abandoned_submission_timeout.ago

    Dir.foreach(in_process_path) do |entry|
      next unless entry.match?(/^\d+$/)

      task_path = File.join(in_process_path, entry)
      next unless File.directory?(task_path)
      next unless File.mtime(task_path) < stale_before

      task = Task.includes(project: [:user, :unit]).find_by(id: entry.to_i)
      next if task.nil?

      if accept_submission_job_present?(task.id)
        Rails.logger.info "Skipping abandoned submission cleanup for task #{task.id} because AcceptSubmissionJob is still active"
        next
      end

      message = "Abandoned in-process submission detected for task #{task.log_details}. The stale in-process folder was older than #{abandoned_submission_timeout / 1.minute} minutes with no active AcceptSubmissionJob, has now been cleared, and the task requires resubmission."
      Rails.logger.error message

      mark_task_for_resubmission(task, message)
      task.clear_in_process
      notify_failed_submission(task, message)
    end
  end

  desc 'Cleanup temporary files'
  task cleanup: [:environment] do
    path = FileHelper.tmp_file_dir

    if Rails.env.development?
      time_offset = 1.minute
    else
      time_offset = 3.hours
    end

    Dir.foreach(path) do |item|
      fname = "#{path}#{item}"
      next if File.directory?(fname)

      if File.mtime(fname) < DateTime.now - time_offset
        begin
          File.delete(fname)
        rescue
          puts "Failed to remove temporary file: #{fname}"
        end
      end
    end

    # Destroy old marking sessions that have less than 1 minute duration
    MarkingSession
      .where("end_time IS NOT NULL AND end_time < ?", 24.hours.ago)
      .where("TIMESTAMPDIFF(SECOND, start_time, end_time) <= ?", 60)
      .find_each(&:destroy!)

    AuthToken.destroy_old_tokens
    clear_abandoned_submissions!
  end

  desc 'Clear abandoned in-process submission folders and notify affected users'
  task clear_abandoned_submissions: [:environment] do
    clear_abandoned_submissions!
  end

  desc 'Remove PDFs from old submissions and archive units'
  task archive_submissions: [:environment] do
    archive_period = Doubtfire::Application.config.unit_archive_after_period
    # Next returns from rake tasks
    next if archive_period <= 1.year

    units = Unit.where(archived: false).where('end_date < :archive_before', archive_before: DateTime.now - archive_period)
    unit_ids = units.pluck(:id)

    loop do
      puts "Are you happy to archive the following units?"
      units.find_each do |unit|
        puts("#{unit.id}: #{unit.detailed_name}") if unit_ids.include?(unit.id)
      end

      puts "Please enter any unit IDs you would like to remove from the list, separated by commas"
      response = $stdin.gets.chomp
      break if response.blank?
      unit_ids_to_exclude = response.split(',').map(&:to_i)

      unit_ids = unit_ids.excluding(unit_ids_to_exclude)

      break if unit_ids.empty?
    end

    # Next returns from rake tasks
    next if unit_ids.empty?

    puts "Proceed? (Yes/No): "
    response = $stdin.gets.chomp
    next unless response == 'Yes'

    Unit.where(id: unit_ids).preload(projects: [:user, { tasks: :task_definition }]).find_each do |unit|
      unit.archive_submissions($stdout)
      unit.update(archived: true)
    end

    puts "Removing old portfolio PDFs"
    `find #{FileHelper.root_portfolio_dir} -name "*pdf.old" -exec rm {} \;`
  end
end
