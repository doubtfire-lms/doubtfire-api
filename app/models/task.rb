class Task < ActiveRecord::Base
  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key

  def overdue?(date=Date.today)
    # A task cannot be overdue if it is marked complete
    # TODO: Fix this. It is fucked and I want to burn it with fire.
    return false if @task_status.name == "Complete"

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = @task_template.recommended_completion_date
    date > recommended_date
  end
end