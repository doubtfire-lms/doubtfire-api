class Task < ActiveRecord::Base
  include ApplicationHelper

  default_scope include:  :task_definition

  attr_accessible :task_definition_id, :project_id, :awaiting_signoff, :completion_date, :task_status_id

  # Model associations
  belongs_to :task_definition         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key
  has_many :sub_tasks, dependent: :destroy

  after_save :update_project

  def self.default
    task_definition             = self.new

    task_definition.name        = "New Task"
    task_definition.description = "Enter a description for this task."
    task_definition.weighting   = 0.0
    task_definition.required    = true
    task_definition.target_date = Date.today

    task_definition
  end

  def update_project
    project.update_attribute(:progress, project.calculate_progress)
    project.update_attribute(:status, project.calculate_status)
  end

  def overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_definition.target_date
    project.reference_date > recommended_date and weeks_overdue >= 1
  end

  def long_overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_definition.target_date
    project.reference_date > recommended_date and weeks_overdue > 2
  end

  def currently_due?
    # A task is currently due if it is not complete and over/under the due date by less than
    # 7 days
    !complete? and days_overdue.between?(-7, 7)
  end

  def weeks_until_due
    days_until_due / 7
  end

  def days_until_due
    (task_definition.target_date - project.reference_date).to_i / 1.day
  end

  def weeks_overdue
    days_overdue / 7
  end

  def days_since_completion
    (project.reference_date - completion_date.to_datetime).to_i / 1.day
  end

  def weeks_since_completion
    days_since_completion / 7
  end

  def days_overdue
    (project.reference_date - task_definition.target_date).to_i / 1.day
  end

  def complete?
    status == :complete
  end

  def fix_and_resubmit?
    status == :fix_and_resubmit
  end

  def fix_and_include?
    status == :fix_and_include
  end

  def redo?
    status == :redo
  end

  def need_help?
    status == :need_help
  end

  def working_on_it?
    status == :working_on_it
  end

  def status
    case task_status.name
    when "Complete"
      :complete
    when "Not Submitted"
      :not_submitted
    when "Fix and Resubmit"
      :fix_and_resubmit
    when "Fix and Include"
      :fix_and_include
    when "Redo"
      :redo
    when "Need Help"
      :need_help
    when "Working On It"
      :working_on_it
    end
  end

  def assess(task_status, assessor)
    # Set the task's status to the assessment outcome status
    # and flag it as no longer awaiting signoff
    self.task_status       = task_status
    self.awaiting_signoff  = false

    # Set the completion date of the task if it's been completed
    if complete?
      self.completion_date = Time.zone.now
    end

    # Save the task
    if save!
      # If a task has been completed, that means the project
      # has definitely started
      project.start

      # If the task was given an assessment outcome
      if assessed?
        # Grab the submission for the task if the user made one
        submission = TaskSubmission.where(task_id: id).order(:submission_time).reverse_order.first
        # Prepare the attributes of the submission
        submission_attributes = {task: self, assessment_time: Time.zone.now, assessor: assessor, outcome: task_status.name}

        # Create or update the submission depending on whether one was made
        if submission.nil?
          TaskSubmission.create! submission_attributes
        else
          submission.update_attributes submission_attributes
          submission.save
        end
      end
    end
  end

  def engage(engagement_status)
    self.task_status       = engagement_status
    self.awaiting_signoff  = false

    if save!
      project.start
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)
    end
  end

  def submit
    self.awaiting_signoff = true

    if save!
      project.start
      submission = TaskSubmission.where(task_id: self.id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: self, submission_time: Time.zone.now)
      else
        if !submission.submission_time.nil? && submission.submission_time < 1.hour.since(Time.zone.now)
          submission.submission_time = Time.zone.now
          submission.save!
        else
          TaskSubmission.create!(task: self, submission_time: Time.zone.now)
        end
      end
    end
  end

  def assessed?
    redo? ||
    fix_and_resubmit? ||
    fix_and_include? ||
    complete?
  end

  def weight
    task_definition.weighting.to_f
  end
end
