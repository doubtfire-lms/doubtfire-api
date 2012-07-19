class Task < ActiveRecord::Base
  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key

  def overdue?(date=Time.zone.now)
    # A task cannot be overdue if it is marked complete
    # TODO: Fix this. It is fucked and I want to burn it with fire.
    return false if self.task_status.name == "Complete"

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = self.task_template.recommended_completion_date
    date > recommended_date
  end

  def long_overdue?(date=Time.zone.now)
    # A task cannot be overdue if it is marked complete
    # TODO: Fix this. It is fucked and I want to burn it with fire.
    return false if status == :complete

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_template.recommended_completion_date
    date > recommended_date and date.weeks_ago(2) > recommended_date
  end

  def status
    case task_status.name
    when "Complete"
      :complete
    when "Needs fixing"
      :fix
    when "Not complete"
      :incomplete
    end
  end
end