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

  def self.task_submission_identifier_path(type, task)
    file_server = Doubtfire::Application.config.student_work_dir
    "#{file_server}/submission_history/#{sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s, task.id.to_s)}"
  end

  def self.task_submission_identifier_path_with_timestamp(type, task, timestamp)
    file_server = Doubtfire::Application.config.student_work_dir
    "#{file_server}/submission_history/#{sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s, task.id.to_s, timestamp.to_s)}"
  end

  def self.submission_history_zip_file_path(task, timestamp)
    submission_identifier_path = task_submission_identifier_path_with_timestamp(:done, task, timestamp)
    "#{submission_identifier_path}/submission.zip"
  end

  def self.create_submission_history_zip_from_new(task, zip_file_path)
    # Generate a zip file for this particular submission with timestamp value and put it here
    task.compress_new_to_done zip_file_path, false
  end

  def self.perform_overseer_submission(task)
    sm_instance = Doubtfire::Application.config.sm_instance
    return false if sm_instance.nil?

    # Proceed only if:
    # unit's assessment is enabled &&
    # task's assessment is enabled &&
    # task definition has an assessment resources zip file &&
    # task has a student submission

    task_definition = task.task_definition
    unit = task_definition.unit

    return false unless unit.assessment_enabled
    return false unless task_definition.assessment_enabled
    return false unless task_definition.has_task_assessment_resources?
    assessment_resources_path = task_definition.task_assessment_resources

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    return false if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?

    # TODO: Probably get rid of it because we may wanna keep routing_key constant [29/nov/2019]
    # if routing_key.nil?, default routing_key that was used
    # to configure the publisher from the .env file will be used automagically.
    # If a default routing_key doesn't exist either, publisher will throw an error.

    # I suppose I also need to add the same checks for routing keys on the PUT/POST
    # apis for task definition, only if assessment_enabled flag is true.
    # Won’t do it for unit’s APIs because a unit may not necessarily have a common
    # routing key for all tasks.. Then again, this isn't the best way to go about this.
    # Best thing is to check it here itself.
    # Old TODO: Add regex check for routing_key.

    timestamp = Time.now.utc.to_i
    zip_file_path = submission_history_zip_file_path(task, timestamp)

    create_submission_history_zip_from_new task, zip_file_path
    unless File.exists? zip_file_path
      logger.error "Student submission history zip file doesn't exist #{zip_file_path}"
      return false
    end

    message = {
      output_path: task_submission_identifier_path_with_timestamp(:done, task, timestamp),
      docker_image_name_tag: docker_image_name_tag,
      submission: zip_file_path,
      assessment: assessment_resources_path,
      timestamp: timestamp,
      task_id: task.id,
      zip_file: 1
    }

    begin
      sm_instance.clients[:ontrack].publisher.connect_publisher
      sm_instance.clients[:ontrack].publisher.publish_message(message)
    rescue RuntimeError => e
      logger.error e
      return false
    ensure
      sm_instance.clients[:ontrack].publisher.disconnect_publisher
    end

    true
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
