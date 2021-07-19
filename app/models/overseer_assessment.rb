class OverseerAssessment < ActiveRecord::Base
  belongs_to :task

  validates :status,                  presence: true
  validates :task_id,                 presence: true
  validates :submission_timestamp,    presence: true

  validates_uniqueness_of :submission_timestamp, scope: :task_id

  enum status: { not_queued: 0, queued: 1, queue_failed: 2, done: 3 }

  # Creates an OverseerAssessment object for a new submission
  def self.create_for(task)
    # Create only if:
    # unit's assessment is enabled &&
    # task's assessment is enabled &&
    # task definition has an assessment resources zip file &&
    # task has a student submission

    task_definition = task.task_definition
    unit = task_definition.unit

    return nil unless unit.assessment_enabled
    return nil unless task_definition.assessment_enabled
    return nil unless task_definition.has_task_assessment_resources?
    return nil unless task.has_new_files? || task.has_done_file?

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    assessment_resources_path = task_definition.task_assessment_resources

    return nil if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?
  
    result = OverseerAssessment.create!(
      task: task,
      status: :not_queued,
      submission_timestamp: Time.now.utc.to_i
    )

    # Create the submission folder and give access
    FileUtils.mkdir_p result.task_submission_with_timestamp_path
    result.grant_access_to_submission

    result.copy_latest_files_to_submission

    result
  end

  def has_submission_files?
    File.exists? submission_zip_file_name
  end

  def submission_zip_file_name
    "#{task_submission_with_timestamp_path}/submission.zip"
  end

  def grant_access_to_submission
    # TODO: Use FACL instead in future.
    `chmod o+w #{task_submission_with_timestamp_path}`
  end

  def copy_latest_files_to_submission
    zip_file_path = submission_zip_file_name

    if task.has_new_files?
      logger.info "Copying new files to submission at: #{zip_file_path}"
      # Generate a zip file for this particular submission with timestamp value and put it here
      task.compress_new_to_done zip_file_path: zip_file_path, rm_task_dir: false
    else
      logger.info "Copying done file to submission at: #{zip_file_path}"
      task.copy_done_to zip_file_path
    end
  end

  def task_submission_with_timestamp_path
    FileHelper.task_submission_identifier_path_with_timestamp(:done, task, submission_timestamp)
  end

  def send_to_overseer()
    logger.info "********* - in perform submission"

    sm_instance = Doubtfire::Application.config.sm_instance
    if sm_instance.nil?
      logger.error "Unable to get service manager to send message to overseer. Unable to send - OverseerAssessment #{id}"
      return false
    end

    unless has_submission_files?
      logger.error "Attempting to send submission to Overseer without associated submission files - OverseerAssessment #{id}"
      return false
    end

    # Proceed only if:
    # unit's assessment is enabled &&
    # task's assessment is enabled &&
    # task definition has an assessment resources zip file &&
    # task has a student submission

    task_definition = task.task_definition
    unit = task_definition.unit

    assessment_resources_path = task_definition.task_assessment_resources

    unless  unit.assessment_enabled && 
            task_definition.assessment_enabled &&
            task_definition.has_task_assessment_resources? &&
            (task.has_new_files? || task.has_done_file?)

      logger.error "Assessment is no longer configured for overseer assessment. Unable to send - OverseerAssessment #{id}"
      return false
    end

    unless File.exists? submission_zip_file_name
      logger.error "Student submission history zip file doesn't exist #{submission_zip_file_name}. Unable to send - OverseerAssessment #{id}"
      return false
    end

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?
      logger.error "No docker image name. Unable to send - OverseerAssessment #{id}"
      return false
    end

    unless File.exists? assessment_resources_path
      logger.error "Unable to fine assessment resources - OverseerAssessment #{id}"
      return false
    end

    logger.info "Sending OverseerAssessment #{id} to message queue"

    message = {
      output_path: task_submission_with_timestamp_path,
      docker_image_name_tag: docker_image_name_tag,
      submission: submission_zip_file_name,
      assessment: assessment_resources_path,
      timestamp: submission_timestamp,
      task_id: task.id,
      overseer_assessment_id: self.id,
      zip_file: 1
    }

    logger.info message.inspect

    begin
      sm_instance.clients[:ontrack].publisher.connect_publisher
      logger.info("Sending message to rabbitmq for Overseer Assessment #{id}")
      sm_instance.clients[:ontrack].publisher.publish_message(message)
      logger.info("Sent to rabbitmq for Overseer Assessment #{id}")
      self.status = :queued
    rescue RuntimeError => e
      logger.error "OverseerAssessment #{id} failed to send: #{e.inspect}"
      self.status = :queue_failed
      return false
    ensure
      logger.info "saving... #{self.status}"
      save!
      sm_instance.clients[:ontrack].publisher.disconnect_publisher
    end

    logger.info "********* - end perform assessment"
    true
  end
end
