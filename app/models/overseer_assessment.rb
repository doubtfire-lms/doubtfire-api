# rubocop:disable Rails/Output
class OverseerAssessment < ApplicationRecord
  belongs_to :task, optional: false
  belongs_to :submission_history, optional: false

  has_one :project, through: :task
  has_many :assessment_comments, as: :commentable, dependent: :destroy
  has_many :overseer_step_results, dependent: :destroy
  has_many :notifications, as: :source, dependent: :destroy

  validates :status,                  presence: true
  validates :task_id,                 presence: true
  validates :submission_timestamp,    presence: true

  validates :submission_timestamp, uniqueness: { scope: :task_id }
  validates :submission_history_id, uniqueness: true
  validate :submission_history_matches_task

  after_update_commit do
    Notification.create_for_overseer(self) if saved_change_to_status? && failed?
  end

  enum :status, { pre_queued: 0, passed: 1, failed: 2 }

  def submission_history_matches_task
    return if submission_history.nil? || task.nil? || submission_history.task_id == task_id

    errors.add(:submission_history, 'must belong to the same task')
  end

  def self.student_notification_grace_period
    Doubtfire::Application.config.overseer_student_notification_grace_period
  end

  scope :awaiting_student_failure_notification, lambda { |grace_period: student_notification_grace_period|
    notification_cutoff = grace_period.ago

    joins(task: { project: :user })
      .joins(<<~SQL.squish)
        INNER JOIN task_comments assessment_comments
          ON assessment_comments.commentable_type = 'OverseerAssessment'
         AND assessment_comments.commentable_id = overseer_assessments.id
         AND assessment_comments.type = 'AssessmentComment'
      SQL
      .joins(<<~SQL.squish)
        LEFT JOIN comments_read_receipts student_read_receipts
          ON student_read_receipts.task_comment_id = assessment_comments.id
         AND student_read_receipts.user_id = projects.user_id
      SQL
      .where(status: statuses[:failed], student_notified_at: nil)
      .where('overseer_assessments.updated_at <= ?', notification_cutoff)
      .where('student_read_receipts.id IS NULL')
      .where(<<~SQL.squish)
        assessment_comments.id = (
          SELECT latest_comment.id
          FROM task_comments latest_comment
          WHERE latest_comment.commentable_type = 'OverseerAssessment'
            AND latest_comment.commentable_id = overseer_assessments.id
            AND latest_comment.type = 'AssessmentComment'
          ORDER BY latest_comment.created_at DESC, latest_comment.id DESC
          LIMIT 1
        )
      SQL
      .where(<<~SQL.squish)
        NOT EXISTS (
          SELECT 1
          FROM overseer_assessments newer_assessments
          WHERE newer_assessments.task_id = overseer_assessments.task_id
            AND (
              newer_assessments.created_at > overseer_assessments.created_at OR
              (
                newer_assessments.created_at = overseer_assessments.created_at AND
                newer_assessments.id > overseer_assessments.id
              )
            )
        )
      SQL
  }

  # TODO: track how many tests ran, and how many tests total at the time
  # TODO: we might not have an overseerStepResult because a new test was added later

  # Creates an OverseerAssessment object for a new submission
  def self.create_for(submission_history, test_submission)
    # Create only if:
    # unit's assessment is enabled &&
    # task's assessment is enabled &&
    # task definition has an assessment resources zip file &&
    # task has a student submission

    task = submission_history.task
    task_definition = task.task_definition
    unit = task_definition.unit

    return nil unless task.overseer_enabled? || test_submission

    active_overseer_steps = task.task_definition.overseer_steps.select(&:enabled)
    return nil if active_overseer_steps.empty?

    docker_image_name_tag = task_definition.docker_image_name_tag || unit.docker_image_name_tag
    # assessment_resources_path = task_definition.task_assessment_resources

    return nil if docker_image_name_tag.nil? || docker_image_name_tag.strip.empty?

    OverseerAssessment.create!(
      task: task,
      submission_history: submission_history,
      status: :pre_queued,
      submission_timestamp: submission_history.submission_timestamp
    )
  end

  delegate :has_submission_files?,
           :submission_zip_file_name,
           :output_path,
           to: :submission_history

  def latest_assessment_comment
    assessment_comments.order(created_at: :desc, id: :desc).first
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
    comment.commentable = self
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

  def send_to_overseer(test_submission: false)
    return { error: "Your task is already queued for processing. Pleasse wait until you receive a response before queueing your task again." } if self.status == :queued

    # TODO: Check status and do not queue if already queued
    puts "********* Sending #{self.id} to overseer"

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

    unless unit.assessment_enabled &&
           (task_definition.assessment_enabled || test_submission) &&
           # task_definition.has_task_assessment_script? &&
           (task.has_new_files? || task.has_done_file?)

      puts "ERROR: Assessment is no longer configured for overseer assessment. Unable to send - OverseerAssessment #{id}"
      return { error: "This assessment is no longer setup for automated feedback. Automated feedback is turned off at either the unit or task level, or the task does not have the scripts needed to automate assessment." }
    end

    unless has_submission_files?
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

    AcceptOverseerJob.perform_async(
      task.id,
      output_path,
      docker_image_name_tag,
      submission_zip_file_name,
      assessment_resources_path,
      submission_timestamp,
      self.id
    )
  end

  def update_from_output(work_dir_path)
    # Update the overseer assessment status
    self.status = :done

    yaml_path = "#{work_dir_path}/output.yaml"


    if File.exist? yaml_path
      yaml_file = YAML.load_file(yaml_path).with_indifferent_access

      comment_txt = ''
      if !yaml_file['build_message'].nil? && !yaml_file['build_message'].strip.empty?
        comment_txt += "Build output:\n"
        comment_txt += if base64?(yaml_file['run_message'])
                         Base64.urlsafe_decode64(yaml_file['build_message'])
                       else
                         yaml_file['run_message']
                       end
        comment_txt += "\n"
      end
      if !yaml_file['run_message'].nil? && !yaml_file['run_message'].strip.empty?
        comment_txt += "\n" unless comment_txt.empty?
        comment_txt += "Execution output:\n"
        comment_txt += if base64?(yaml_file['run_message'])
                         Base64.urlsafe_decode64(yaml_file['run_message'])
                       else
                         yaml_file['run_message']
                       end
        comment_txt += "\n"
      end

      if !yaml_file['message'].nil? && !yaml_file['message'].strip.empty?
        comment_txt += "\n" unless comment_txt.empty?
        comment_txt += "Message:\n"
        comment_txt += yaml_file['message']
      end

      if comment_txt.present?
        update_assessment_comment(comment_txt[0, 4000]) # Truncate to 4000 characters
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
        task.add_status_comment(task.task_definition.unit.main_convenor.user, new_status)
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

  def base64?(value)
    value.is_a?(String) && Base64.strict_encode64(Base64.decode64(value)) == value
  end


  def passed_steps
    overseer_step_results.select(&:pass).size
  end
end
# rubocop:enable Rails/Output
