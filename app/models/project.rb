class Project < ActiveRecord::Base

  # TODO: Remove this once each project has an individual weight.
  # For now, this assumes that the project is core (i.e. non-optional)
  # and it its completion is worth a credit
  DEFAULT_PROJECT_WEIGHT = 0.65

  attr_accessible :project_role

  # Model associations
  belongs_to :team              # Foreign key
  belongs_to :project_status    # Foreign key
  belongs_to :project_template  # Foreign key
  belongs_to :team_membership   # Foreign key

  has_many :tasks

  def health(date=Date.today)
    completed_tasks_weight        = completed_tasks.empty? ? 0.0 : completed_tasks.map{|task| task.task_template.weighting }.inject(:+)
    recommended_remaining_weight  = recommended_completed_tasks(date).empty? ? 0.0 : recommended_completed_tasks(date).map{|task| task.task_template.weighting }.inject(:+)

    # Project health is at 100% when the project is yet to start
    return 1.0 unless has_commenced?

    relative_health = (completed_tasks_weight / recommended_remaining_weight)

    # If relative health is NaN (i.e. either completed or recommended is 0)
    # then return 0 if it's completed tasks (i.e. no tasks have been completed),
    # otherwise 1.0, because tasks have been completed, but none are expected
    # to have been completed
    if relative_health.nan?
      completed_tasks_weight == 0.0 ? 0.0 : 1.0
    else
      [relative_health * weight, 1.0].min
    end
  end

  def relative_progress
    project_health = health

    if health > 0.75
      :ahead
    elsif health >= 0.5 and health <= 0.75
      :on_track
    elsif health >= 0.25 and health < 0.5
      :behind
    elsif health >= 0.10 and health < 0.25
      :danger
    else
      :doomed
    end
  end

  def projected_end_date(date=Date.today)
    return project_template.end_date if rate_of_completion == 0.0

    (remaining_tasks_weight / rate_of_completion).ceil.days.since date
  end

  def rate_of_completion(date=Date.today)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if !has_commenced?

    # Determine the number of weeks elapsed
    project_days_elapsed = (date - project_template.start_date.to_datetime).to_i

    # TODO: Might make sense to take in the resolution (i.e. days, weeks), rather
    # than just assuming days
    completed_tasks_weight / project_days_elapsed
  end

  def required_task_completion_rate(date=Date.today)
    # Determine the number of weeks elapsed
    project_days_remaining = (project_template.end_date.to_datetime - date).to_i

    remaining_tasks_weight / project_days_remaining
  end

  def recommended_completed_tasks(date=Date.today)
    tasks.select{|task| task.task_template.recommended_completion_date < date }
  end

  def completed_tasks
    tasks.select{|task| task.task_status.name == "Complete" }
  end

  def incomplete_tasks
    tasks.select{|task| task.task_status.name != "Complete" }
  end

  def remaining_tasks_weight
    incomplete_tasks.empty? ? 0.0 : incomplete_tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def completed_tasks_weight
    completed_tasks.empty? ? 0.0 : completed_tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def total_task_weight
    tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def overdue_tasks(date=Date.today)
    tasks.select{|task| task.overdue? date }
  end

  def has_commenced?
    Time.zone.now > project_template.start_date
  end

  def has_concluded?
    Time.zone.now > project_template.end_date
  end

  def weight
    DEFAULT_PROJECT_WEIGHT
  end
end