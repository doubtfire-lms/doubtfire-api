class PortfolioEvidence
  include FileHelper
  include LogHelper

  def self.logger
    LogHelper::logger
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

  #
  # Process enqueued pdfs in each folder of the :new directory
  # into PDF files
  #
  def self.process_new_to_pdf
    done = { }
    errors = { }

    # For each folder in new (i.e., queued folders to process) that matches appropriate name
    new_root_dir = Dir.entries(student_work_dir(:new)).select { | f | (f =~ /^\d+$/) == 0 }
    new_root_dir.each do | folder_id |
      begin
        task = Task.find(folder_id)
        logger.info "creating pdf for task #{task.id}"
        task.convert_submission_to_pdf

        if done[task.project].nil?
          done[task.project] = []
        end
        done[task.project] << task
      rescue Exception => e
        puts "Failed to process folder_id = #{folder_id} #{e.message}"
        logger.error "Failed to process folder_id = #{folder_id} #{e.message}"

        if task
          task.add_comment task.project.main_tutor, "**Automated Comment**: Something went wrong with your submission. Check the files and resubmit this task."
          task.trigger_transition 'fix', task.project.main_tutor

          if errors[task.project].nil?
            errors[task.project] = []
          end
          errors[task.project] << task
        end
      end
    end

    done.each do |project, tasks|
      logger.info "checking email for project #{project.id}"
      if project.student.receive_task_notifications
        logger.info "emailing task notification to #{project.student.name}"
        PortfolioEvidenceMailer.task_pdf_ready_message(project, tasks).deliver
      end
    end

    errors.each do |project, tasks|
      logger.info "checking email for project #{project.id}"
      if project.student.receive_task_notifications
        logger.info "emailing task notification to #{project.student.name}"
        PortfolioEvidenceMailer.task_pdf_failed(project, tasks).deliver
      end
    end
  end

  def self.final_pdf_path_for_group_submission(group_submission)
    File.join(
      FileHelper.student_group_work_dir(:pdf, group_submission, task=nil, create=true),
      sanitized_filename(
        sanitized_path("#{group_submission.task_definition.abbreviation}-#{group_submission.id}") + ".pdf"))
  end

  def self.recreate_task_pdf(task)
    task.move_done_to_new()
  end
end
