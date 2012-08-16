class Task < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key

  def overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.target_date
    reference_date > recommended_date and weeks_overdue >= 1
  end

  def long_overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.target_date
    reference_date > recommended_date and weeks_overdue > 2
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
    (task_template.target_date - reference_date).to_i / 1.day
  end

  def weeks_overdue
    days_overdue / 7
  end

  def days_overdue
    (reference_date - task_template.target_date).to_i / 1.day
  end

  def complete?
    status == :complete
  end

  def needs_fixing?
    status == :needs_fixing
  end

  def status
    case task_status.name
    when "Complete"
      :complete
    when "Not Submitted"
      :not_submitted
    when "Needs Fixing"
      :needs_fixing
    end
  end

  def weight
    task_template.weighting.to_f
  end
end