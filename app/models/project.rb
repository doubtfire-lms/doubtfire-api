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

  def recommended_completed_tasks(date=Date.today)
    tasks.select{|task| task.task_template.recommended_completion_date < date }
  end

  def completed_tasks
    tasks.select{|task| task.task_status.name == "Complete" }
  end

  def incomplete_tasks
    tasks.select{|task| task.task_status.name != "Complete" }
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