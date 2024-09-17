# rubocop:disable Rails/Output
class OverseerAssessment < ApplicationRecord
  belongs_to :task, optional: false

  has_one :project, through: :task
  has_many :assessment_comments, dependent: :destroy

  validates :status,                  presence: true
  validates :task_id,                 presence: true
  validates :submission_timestamp,    presence: true

  validates :submission_timestamp, uniqueness: { scope: :task_id }

  enum status: { pre_queued: 0, queued: 1, queue_failed: 2, done: 3 }

  after_destroy :delete_associated_files

  # Creates an OverseerAssessment object for a new submission
  def self.create_for(task)
    # Create only if:
    # unit's assessment is enabled &&
    # task's assessment is enabled &&
    # task definition has an assessment resources zip file &&
    # task has a student submission

    task_definition = task.task_definition
    unit = task_definition.unit

    return nil unless task.overseer_enabled?

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    assessment_resources_path = task_definition.task_assessment_resources

    return nil if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?

    result = OverseerAssessment.create!(
      task: task,
      status: :pre_queued,
      submission_timestamp: Time.now.utc.to_i
    )

    # Create the submission folder and give access
    FileUtils.mkdir_p result.output_path
    result.grant_access_to_submission

    result.copy_latest_files_to_submission

    result
  end

  def has_submission_files?
    File.exist? submission_zip_file_name
  end

  def submission_zip_file_name
    "#{output_path}/submission.zip"
  end

  def grant_access_to_submission
    # TODO: Use FACL instead in future.
    `chmod o+w #{output_path}`
  end

  def copy_latest_files_to_submission
    zip_file_path = submission_zip_file_name

    if task.has_new_files?
      puts "Copying new files to submission at: #{zip_file_path}"
      # Generate a zip file for this particular submission with timestamp value and put it here
      task.compress_new_to_done zip_file_path: zip_file_path, rm_task_dir: false, rename_files: true
    else
      puts "Copying done file to submission at: #{zip_file_path}"
      task.copy_done_to zip_file_path
    end
  end

  # Path to where the submission and output are stored - includes the submission when it is to be processed
  def output_path
    FileHelper.task_submission_identifier_path_with_timestamp(:done, task, submission_timestamp)
  end

  def add_assessment_comment(text = 'Automated Assessment Started')
    text.strip!
    return nil if text.blank?

    tutor = project.tutor_for(task.task_definition)

    # Need to ensure all group members have a task...
    task.ensured_group_submission if task.group_task? && task.group

    comment = AssessmentComment.create
    comment.task = task
    comment.user = tutor
    comment.comment = text
    comment.recipient = project.student
    comment.overseer_assessment = self
    comment.save!

    comment
  end

  def update_assessment_comment(text)
    text.strip!
    return nil if text.blank?

    assessment_comment = assessment_comments.last

    # Don't add if there is already a task assessment comment for this task
    if assessment_comment.present?
      # In case the main tutor changes
      assessment_comment.comment = text
      assessment_comment.save!

      return assessment_comment
    end

    puts "WARN: Unexpected need to create assessment comment for OverseerAssessment: #{self.id}"
    add_assessment_comment text
  end

  def send_to_overseer()
    return { error: "Your task is already queued for processing. Pleasse wait until you receive a response before queueing your task again." } if self.status == :queued

    # TODO: Check status and do not queue if already queued
    puts "********* Sending #{self.id} to overseer"

    sm_instance = Doubtfire::Application.config.sm_instance
    if sm_instance.nil?
      puts "ERROR: Unable to get service manager to send message to overseer. Unable to send - OverseerAssessment #{id}"
      return { error: "Automated feedback is not configured correctly. Please raise an issue with your administrator. ERR:O1" }
    end

    unless has_submission_files?
      puts "ERROR: Attempting to send submission to Overseer without associated submission files - OverseerAssessment #{id}"
      return { error: "Your submission does not include any files to be processed." }
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

      puts "ERROR: Assessment is no longer configured for overseer assessment. Unable to send - OverseerAssessment #{id}"
      return { error: "This assessment is no longer setup for automated feedback. Automated feedback is turned off at either the unit or task level, or the task does not have the scripts needed to automate assessment." }
    end

    unless File.exist? submission_zip_file_name
      puts "ERROR: Student submission history zip file doesn't exist #{submission_zip_file_name}. Unable to send - OverseerAssessment #{id}"
      return { error: "We no longer have the files associated with this submission. Please test a later submission, or upload your work again." }
    end

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?
      puts "ERROR: No docker image name. Unable to send - OverseerAssessment #{id}"
      return { error: "This task is not configured to use automated feedback. Please ask your tutor to check the configuration for the task for the associated Docker image." }
    end

    puts "Sending OverseerAssessment #{id} to message queue"

    message = {
      output_path: output_path,
      docker_image_name_tag: docker_image_name_tag,
      submission: submission_zip_file_name,
      assessment: assessment_resources_path,
      timestamp: submission_timestamp,
      task_id: task.id,
      overseer_assessment_id: self.id,
      zip_file: 1
    }

    puts message.inspect

    begin
      sm_instance.clients[:ontrack].publisher.connect_publisher
      puts("Sending message to rabbitmq for Overseer Assessment #{id}")
      sm_instance.clients[:ontrack].publisher.publish_message(message)
      puts("Sent to rabbitmq for Overseer Assessment #{id}")
      self.status = :queued
    rescue RuntimeError => e
      puts "ERROR: OverseerAssessment #{id} failed to send: #{e.inspect}"
      self.status = :queue_failed
      return { error: "We are unable to send your submission to the automated feedback service. Please try again later." }
    ensure
      puts "saving... #{self.status}"
      save!
      sm_instance.clients[:ontrack].publisher.disconnect_publisher
    end

    puts "********* - end perform assessment"
    if assessment_comments.count == 0
      result = add_assessment_comment()
    else
      result = assessment_comments.last
      result.update created_at: Time.zone.now
      result
    end

    {
      comment: result,
      error: nil
    }
  end

  def update_from_output()
    # Update the overseer assessment status
    self.status = :done

    yaml_path = "#{output_path}/output.yaml"

    if File.exist? yaml_path
      yaml_file = YAML.load_file(yaml_path).with_indifferent_access

      comment_txt = ''
      if !yaml_file['build_message'].nil? && !yaml_file['build_message'].strip.empty?
        comment_txt += yaml_file['build_message']
      end
      if !yaml_file['run_message'].nil? && !yaml_file['run_message'].strip.empty?
        comment_txt += "\n\n" unless comment_txt.empty?
        comment_txt += yaml_file['run_message']
      end

      if comment_txt.present?
        update_assessment_comment(comment_txt)
      else
        puts 'YAML file doesn\'t contain field `build_message` or `run_message`'
      end

      new_status = nil
      if yaml_file['new_status'].present?
        new_status = TaskStatus.status_for_name(yaml_file['new_status'])
        self.result_task_status = new_status ? new_status.status_key : task.status
      else
        puts 'YAML file doesn\'t contain field `new_status`'
        self.result_task_status = task.status
      end

      if task.ready_for_feedback? && new_status.present?
        task.update task_status: new_status
      end
    else
      puts "File #{yaml_path} doesn't exist"
      self.result_task_status = task.status
    end
  rescue StandardError => e
    puts ERROR: e
  ensure
    self.save!
  end

  def delete_associated_files
    FileUtils.rm_rf output_path
  end
end
# rubocop:enable Rails/Output
