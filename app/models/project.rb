class Project < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :project_template, :team_membership, :project_role, :started, :progress

  # Model associations
  belongs_to :team              # Foreign key
  belongs_to :project_template  # Foreign key
  belongs_to :team_membership, :dependent => :destroy   # Foreign key

  has_one :user, through: :team_membership
  has_many :tasks, :dependent => :destroy   # Destroying a project will also nuke all of its tasks

  before_create :calculate_temporal_attributes

  scope :with_progress, lambda {|progress_types|
    where(progress: progress_types) unless progress_types.blank?
  }

  default_scope :include => :project_template

  def reference_date
    if Time.zone.now > project_template.end_date
      project_template.end_date
    else
      Time.zone.now
    end
  end

  def assigned_tasks
    required_tasks
  end

  def required_tasks
    tasks.select{|task| task.task_template.required? }
  end

  def optional_tasks
    tasks.select{|task| !task.task_template.required? }
  end

  def progress
    read_attribute(:progress).to_sym
  end

  def progress=(value)
    write_attribute(:progress, value.to_s)
  end

  def status
    read_attribute(:status).to_sym
  end

  def status=(value)
    write_attribute(:status, value.to_s)
  end

  def calculate_temporal_attributes
    progress  = calculate_progress
    status    = calculate_status
  end

  def calculate_progress
    relative_progress      = progress_in_weeks

    if relative_progress >= 0
      :ahead
    elsif relative_progress == -1 or relative_progress == -2
      :on_track
    else
      weeks_behind = relative_progress.abs

      if weeks_behind <= 3
        :behind
      elsif weeks_behind > 3 and weeks_behind <= 5
        :danger
      else
        :doomed
      end
    end
  end

  def calculate_status
    if !commenced?
      :not_commenced
    elsif concluded?
      completed? ? :completed : :not_completed
    else
      if completed?
        :completed
      elsif started?
        :in_progress
      else
        :not_started
      end
    end
  end

  def progress_in_weeks
    progress_in_days / 7
  end

  def progress_in_days
    units_completed = task_units_completed

    current_week  = weeks_elapsed
    date_progress = project_template.start_date

    progress_points.each do |date, weight|
      break if weight > units_completed
      date_progress = date
    end
    
    (date_progress - reference_date).to_i / 1.day
  end

  def progress_points
    date_accumulated_weight_map = {}

    assigned_tasks.sort{|a, b| a.task_template.target_date <=>  b.task_template.target_date}.each do |project_task|
      date_accumulated_weight_map[project_task.task_template.target_date] = assigned_tasks.select{|task| 
        task.task_template.target_date <= project_task.task_template.target_date
      }.map{|task| task.task_template.weighting.to_f}.inject(:+)
    end

    date_accumulated_weight_map
  end

  def projected_end_date
    return project_template.end_date if rate_of_completion == 0.0
    (remaining_tasks_weight / rate_of_completion).ceil.days.since reference_date
  end

  def weeks_elapsed
    days_elapsed / 7
  end

  def days_elapsed(date=nil)
    date ||= reference_date
    (date - project_template.start_date).to_i / 1.day
  end

  def rate_of_completion(date=nil)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if !commenced? or completed_tasks.empty?
    date ||= reference_date

    # TODO: Might make sense to take in the resolution (i.e. days, weeks), rather
    # than just assuming days

    # If on the first day (i.e. a day has not yet passed, but the project
    # has commenced), force days elapsed to be 1 to avoid divide by zero
    days = days_elapsed(date)
    days = 1 if days_elapsed(date) < 1

    completed_tasks_weight / days.to_f
  end

  def required_task_completion_rate
    remaining_tasks_weight / remaining_days
  end

  def recommended_completed_tasks
    assigned_tasks.select{|task| task.task_template.target_date < reference_date }
  end

  def completed_tasks
    assigned_tasks.select{|task| task.complete? }
  end

  def partially_completed_tasks
    # TODO: Should probably have a better definition
    # of partially complete than just 'needs fixing' tasks
    assigned_tasks.select{|task| task.needs_fixing? }
  end

  def completed?
    # TODO: Have a status flag on the project instead
    assigned_tasks.all?{|task| task.complete? }
  end

  def incomplete_tasks
    assigned_tasks.select{|task| !task.complete? }
  end

  def percentage_complete
    completed_tasks.empty? ? 0.0 : (completed_tasks_weight / total_task_weight) * 100
  end

  def remaining_tasks_weight
    incomplete_tasks.empty? ? 0.0 : incomplete_tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def completed_tasks_weight
    completed_tasks.empty? ? 0.0 : completed_tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def partially_completed_tasks_weight
    # Award half for partially completed tasks
    # TODO: Should probably make this a project-by-project option
    partially_complete = partially_completed_tasks
    partially_complete.empty? ? 0.0 : partially_complete.map{|task| task.task_template.weighting / 2.to_f }.inject(:+)
  end

  def task_units_completed
    completed_tasks_weight + partially_completed_tasks_weight
  end

  def total_task_weight
    assigned_tasks.map{|task| task.task_template.weighting }.inject(:+)
  end

  def currently_due_tasks
    assigned_tasks.select{|task| task.currently_due? }
  end

  def overdue_tasks
    assigned_tasks.select{|task| task.overdue? }
  end

  def remaining_days
    (project_template.end_date - reference_date).to_i / 1.day
  end

  def in_progress?
    commenced? && !concluded?
  end

  def commenced?
    reference_date >= project_template.start_date
  end

  def concluded?
    reference_date > project_template.end_date
  end

  def has_optional_tasks?
    tasks.any?{|task| !task.task_template.required }
  end

  def last_task_completed
    completed_tasks.sort{|a, b| a.completion_date <=> b.completion_date }.last
  end
end