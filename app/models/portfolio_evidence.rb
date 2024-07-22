class PortfolioEvidence
  include FileHelper

  def self.logger
    Rails.logger
  end

  def self.sanitized_path(*paths)
    FileHelper.sanitized_path *paths
  end

  def self.sanitized_filename(filename)
    FileHelper.sanitized_filename(filename)
  end

  def self.student_work_dir(type = nil, task = nil, create = true)
    FileHelper.student_work_dir(type, task, create)
  end

  # Move all tasks to a folder with this process's id in "in_process"
  def self.move_to_pid_folder
    pid_folder = File.join(student_work_dir(:in_process), "pid_#{Process.pid}")

    # Move everything in "new" to "pid" folder but retain the old "new" folder
    FileHelper.move_files(student_work_dir(:new), pid_folder, true, DateTime.now - 1.minute)
    pid_folder
  end

  #
  # Process enqueued pdfs in each folder of the :new directory
  # into PDF files
  #
  def self.process_new_to_pdf(my_source)
    done = {}
    errors = {}

    # For each folder in new (i.e., queued folders to process) that matches appropriate name
    new_root_dir = Dir.entries(my_source).select do |f|
      (f =~ /^\d+$/) == 0
    end
    new_root_dir.each do |folder_id|
      begin
        task = Task.find(folder_id)
      rescue
        logger.error("Failed to find task with id #{folder_id} during PDF generation")
        next
      end

      add_error = lambda do |message|
        logger.error "Failed to process folder_id = #{folder_id}. #{message}"

        if task
          errors[task.project] = [] if errors[task.project].nil?
          errors[task.project] << task
        end
      end

      begin
        logger.info "creating pdf for task #{task.id}"
        success = task.convert_submission_to_pdf(source_folder: my_source, log_to_stdout: true)

        if success
          done[task.project] = [] if done[task.project].nil?
          done[task.project] << task
        else
          add_error.call('Failed to convert your submission to pdf.')
        end
      rescue Exception => e
        add_error.call(e.message.to_s)
      end
    end

    errors.each do |project, tasks|
      logger.debug "checking email for project #{project.id}"
      next unless project.student.receive_task_notifications

      logger.info "emailing task notification to #{project.student.name}"
      begin
        PortfolioEvidenceMailer.task_pdf_failed(project, tasks).deliver
      rescue StandardError => e
        logger.error "Failed to send task pdf failed email for project #{project.id}!\n#{e.message}"
      end
    end
  end

  def self.final_pdf_path_for_group_submission(group_submission)
    File.join(
      FileHelper.student_group_work_dir(:pdf, group_submission, task = nil, create = true),
      sanitized_filename(
        sanitized_path("#{group_submission.task_definition.abbreviation}-#{group_submission.id}") + '.pdf'
      )
    )
  end

  def self.recreate_task_pdf(task)
    task.move_done_to_new
  end
end
