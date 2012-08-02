class Task < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key

  def overdue?
    # A task cannot be overdue if it is marked complete
    return false if task.complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = self.task_template.recommended_completion_date
    reference_date > recommended_date
  end

  def long_overdue?
    # A task cannot be overdue if it is marked complete
    return false if task.complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.recommended_completion_date
    reference_date > recommended_date and date.weeks_ago(2) > recommended_date
  end

  def complete?
    status == :complete
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
end