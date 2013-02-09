class Task < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :task_template_id, :project_id, :awaiting_signoff, :completion_date, :task_status_id

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key

  after_save :update_project

  default_scope :include => :task_template

  def update_project
    project.update_attribute(:progress, project.calculate_progress)
    project.update_attribute(:status, project.calculate_status)
  end

  def overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.target_date
    project.reference_date > recommended_date and weeks_overdue >= 1
  end

  def long_overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.target_date
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
    (task_template.target_date - project.reference_date).to_i / 1.day
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
    (project.reference_date - task_template.target_date).to_i / 1.day
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

  def weight
    task_template.weighting.to_f
  end
end