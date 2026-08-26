require_all 'lib/helpers'
require 'sidekiq/api'

# rubocop:disable Metrics/BlockLength
namespace :maintenance do
  def sidekiq_job_present_in_workers_or_default_queue?(&matcher)
    Sidekiq::Workers.new.each do |_process_id, _thread_id, work|
      payload = work['payload'].is_a?(String) ? JSON.parse(work['payload']) : work['payload']

      return true if matcher.call(payload['class'], payload['args'])
    end

    # TODO: We may need to iterate through each queue when we implement parallel sidekiq jobs
    Sidekiq::Queue.new("default").each do |job|
      return true if matcher.call(job.klass, job.args)
    end

    false
  end

  def accept_submission_job_matches_task?(job_class, job_args, task_id)
    job_class == 'AcceptSubmissionJob' && job_args.first.to_i == task_id
  end

  def accept_submission_job_present?(task_id)
    sidekiq_job_present_in_workers_or_default_queue? do |job_class, job_args|
      accept_submission_job_matches_task?(job_class, job_args, task_id)
    end
  end

  def accept_overseer_job_matches_assessment?(job_class, job_args, overseer_assessment_id)
    job_class == 'AcceptOverseerJob' && job_args.last.to_i == overseer_assessment_id
  end

  def accept_overseer_job_present?(overseer_assessment_id)
    sidekiq_job_present_in_workers_or_default_queue? do |job_class, job_args|
      accept_overseer_job_matches_assessment?(job_class, job_args, overseer_assessment_id)
    end
  end

  def create_submission_history_job_present?(task_id)
    sidekiq_job_present_in_workers_or_default_queue? do |job_class, job_args|
      job_class == 'CreateSubmissionHistoryJob' && job_args.first.to_i == task_id
    end
  end

  def notify_failed_submission(task, message)
    Notification.create_pdf_failure(task)

    if NotificationSetting.for(task.project.student).delivers?(task.unit, 'pdf_generation_failed', :email)
      begin
        PortfolioEvidenceMailer.task_pdf_failed(task.project, [task]).deliver_now
      rescue StandardError => e
        Rails.logger.error "Failed to send task pdf failed email for project #{task.project.id}!\n#{e.message}"
      end
    end

    if defined?(Sentry)
      Sentry.capture_message(
        "Cleared abandoned in-process submission for task #{task.id}",
        level: :info,
        extra: {
          task_id: task.id,
          task_definition: task.task_definition.abbreviation,
          username: task.project.user.username,
          detail: message
        }
      )
    end

    begin
      exception = StandardError.new(message)
      mail = ErrorLogMailer.error_message('Accept Submission Cleanup', message, exception)
      mail.deliver_now if mail.present?
    rescue StandardError => e
      Rails.logger.error "Failed to send error log to admin for task #{task.id}!\n#{e.message}"
    end
  end

  def mark_task_for_resubmission(task, _message)
    tutor = task.project.tutor_for(task.task_definition)

    task.trigger_transition(trigger: 'fix', by_user: tutor)
    task.add_text_comment(
      tutor,
      "**Automated Comment**: Something went wrong with compiling your submission. Please resubmit the task.",
      attention_audience: :student
    )
  rescue StandardError => e
    Rails.logger.error "Failed to move task #{task.id} to fix and add automated comment!\n#{e.message}"
  end

  def mark_task_for_overseer_resubmission(task)
    tutor = task.project.tutor_for(task.task_definition)

    task.trigger_transition(trigger: 'fix', by_user: tutor)
    task.add_text_comment(
      tutor,
      "**Automated Comment**: Something went wrong while running the automated tests for this submission. Please resubmit the task.",
      attention_audience: :student
    )
  rescue StandardError => e
    Rails.logger.error "Failed to move task #{task.id} to fix and add Overseer automated comment!\n#{e.message}"
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
        Rails.logger.info "Skipping abandoned submission cleanup for task #{task.id} because AcceptSubmissionJob is still running or queued"
        next
      end

      message = "Abandoned in-process submission detected for task #{task.log_details}. The stale in-process folder was older than #{abandoned_submission_timeout / 1.minute} minutes with no running or queued AcceptSubmissionJob, has now been cleared, and the task requires resubmission."
      Rails.logger.error message

      mark_task_for_resubmission(task, message)
      task.clear_in_process
      notify_failed_submission(task, message)
    end
  end

  def clear_abandoned_overseer_assessments!
    abandoned_assessment_timeout = 10.minutes
    stale_before = abandoned_assessment_timeout.ago

    OverseerAssessment
      .pre_queued
      .includes(task: [project: :user])
      .where('created_at < ?', stale_before)
      .find_each do |assessment|
      if accept_overseer_job_present?(assessment.id)
        Rails.logger.info "Skipping abandoned OverseerAssessment cleanup for assessment #{assessment.id} because AcceptOverseerJob is still running or queued"
        next
      end

      task = assessment.task
      message = "Abandoned OverseerAssessment detected for task #{task.log_details}. Assessment #{assessment.id} remained pre_queued for more than #{abandoned_assessment_timeout / 1.minute} minutes with no running or queued AcceptOverseerJob and has been marked failed."
      Rails.logger.error message

      assessment.update!(status: :failed)
      mark_task_for_overseer_resubmission(task)

      if defined?(Sentry)
        Sentry.capture_message(
          "Marked stale OverseerAssessment failed for task #{task.id}",
          level: :warning,
          extra: {
            task_id: task.id,
            overseer_assessment_id: assessment.id,
            task_definition: task.task_definition.abbreviation,
            username: task.project.user.username,
            detail: message
          }
        )
      end
    end
  end

  def clear_abandoned_submission_history_markers!
    stale_before = 10.minutes.ago
    marker_pattern = File.join(FileHelper.root_submission_history_dir, '**', 'pending', '*', 'submission-history')

    Dir.glob(marker_pattern).each do |marker_path|
      next unless File.mtime(marker_path) < stale_before

      task_id = File.basename(File.dirname(marker_path)).to_i
      next if create_submission_history_job_present?(task_id)

      Rails.logger.error "Clearing abandoned submission history marker for task #{task_id}"
      FileUtils.rm_f(marker_path)
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
    clear_abandoned_submission_history_markers!
    clear_abandoned_overseer_assessments!
  end

  desc 'Clear abandoned in-process submission folders and notify affected users'
  task clear_abandoned_submissions: [:environment] do
    clear_abandoned_submissions!
  end

  desc 'Clear abandoned pre-queued Overseer assessments and request resubmission'
  task clear_abandoned_overseer_assessments: [:environment] do
    clear_abandoned_overseer_assessments!
  end

  desc 'Clear stale submission history markers with no queued or running job'
  task clear_abandoned_submission_history_markers: [:environment] do
    clear_abandoned_submission_history_markers!
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
# rubocop:enable Metrics/BlockLength
