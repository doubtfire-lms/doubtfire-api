class PortfolioEvidence
  include FileHelper
  include LogHelper

  def self.logger
    LogHelper.logger
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
    done = {}
    errors = {}

    # For each folder in new (i.e., queued folders to process) that matches appropriate name
    new_root_dir = Dir.entries(student_work_dir(:new)).select do |f|
      # rubocop:disable Style/NumericPredicate
      (f =~ /^\d+$/) == 0
      # rubocop:enable Style/NumericPredicate
    end
    new_root_dir.each do |folder_id|
      task = Task.find(folder_id)

      add_error = lambda do |message|
        logger.error "Failed to process folder_id = #{folder_id}. #{message}"

        if task
          task.add_text_comment task.project.main_tutor, "**Automated Comment**: Something went wrong with your submission. Check the files and resubmit this task. #{message}"
          task.trigger_transition trigger: 'fix', by_user: task.project.main_tutor

          errors[task.project] = [] if errors[task.project].nil?
          errors[task.project] << task
        end
      end

      begin
        logger.info "creating pdf for task #{task.id}"
        success = task.convert_submission_to_pdf

        if success
          perform_overseer_submission task
          done[task.project] = [] if done[task.project].nil?
          done[task.project] << task
        else
          add_error.call('Failed to convert your submission to pdf.')
        end
      rescue Exception => e
        add_error.call(e.message.to_s)
      end
    end

    # Remove email of task notification success - only email on fail
    # done.each do |project, tasks|
    #   logger.info "checking email for project #{project.id}"
    #   if project.student.receive_task_notifications
    #     logger.info "emailing task notification to #{project.student.name}"
    #     PortfolioEvidenceMailer.task_pdf_ready_message(project, tasks).deliver
    #   end
    # end

    errors.each do |project, tasks|
      logger.info "checking email for project #{project.id}"
      if project.student.receive_task_notifications
        logger.info "emailing task notification to #{project.student.name}"
        PortfolioEvidenceMailer.task_pdf_failed(project, tasks).deliver
      end
    end
  end

  def self.required_zip_file_path(file_server, type, task)
    sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s, task.id.to_s)
  end

  def self.submission_history_zip_file_path(task)
    file_server = Doubtfire::Application.config.student_work_dir
    temp_path = required_zip_file_path(file_server, :done, task)
    "#{file_server}/submission_history/#{temp_path}/#{Time.now.utc.to_i}.zip"
  end

  def self.create_submission_history_zip_from_new(task, zip_file_path)
    # read_path = "#{file_server}/new/#{task.id}"

    # Generate a zip file for this particular submission with timestamp value and put it here
    task.compress_new_to_done zip_file_path, false
  end

  def self.perform_overseer_submission(task)
    sm_instance = Doubtfire::Application.config.sm_instance
    return if sm_instance.nil?

    # TODO: Add all the checks:
    # if unit's assessment is enabled &&
    # if task's assessment is enabled &&
    # if task definition has assessment resources zip file &&
    # if task has submission zip file, then publish

    task_definition = task.task_definition

    return unless task_definition.has_task_assessment_resources?

    assessment_resources_path = task_definition.task_assessment_resources
    puts assessment_resources_path

    zip_file_path = submission_history_zip_file_path(task)
    puts zip_file_path

    create_submission_history_zip_from_new task, zip_file_path
    unless File.exists? zip_file_path
      puts "Student submission history zip file doesn't exist #{zip_file_path}"
      return
    end

    message = {
      submission: zip_file_path,
      assessment: assessment_resources_path,
      task_id: task.id,
      zip_file: 1
    }

    sm_instance = Doubtfire::Application.config.sm_instance
    sm_instance.clients[:ontrack].publisher.connect_publisher
    sm_instance.clients[:ontrack].publisher.publish_message(message)
    sm_instance.clients[:ontrack].publisher.disconnect_publisher

    # overseer_response = RestClient.post "http://localhost:9292/submit", {'project_id' => task.project.id, 'submission' => File.new(submission_path, 'rb'), 'assessment' => File.new(assessment_resources_path, 'rb')}
    # pdf_file = overseer_response

    # TODO: Create an pdf.erb for displaying the result and adding it as a task comment.
    # task.add_comment_with_attachment task.project.main_tutor, pdf_file
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
