class Float
  def signif(signs)
    Float("%.#{signs}f" % self)
  end
end

class Project < ActiveRecord::Base
  include ApplicationHelper

  def self.permissions
    { 
      student: [ :get ],
      tutor: [ :get, :trigger_week_end ],
      nil => []
    }
  end

  def role_for(user)
    return user_role(user)
  end  

  belongs_to :unit
  belongs_to :unit_role, class_name: 'UnitRole', foreign_key: 'unit_role_id', dependent: :destroy

  # has_one :user, through: :student
  has_many :tasks, dependent: :destroy   # Destroying a project will also nuke all of its tasks

  before_create :calculate_temporal_attributes

  scope :with_progress, lambda {|progress_types|
    where(progress: progress_types) unless progress_types.blank?
  }

  def self.for_user(user)
    joins(:unit_role).where('unit_roles.user_id = :user_id', user_id: user.id)
  end

  def self.for_unit_role(unit_role)
    if unit_role.is_student?
      Project.where(unit_role_id: unit_role.id)
    elsif unit_role.is_teacher?
      Project.where(unit_id: unit_role.unit_id)
    else
      nil
    end
  end

  #
  # All "discuss" become complete
  #
  def trigger_week_end( by_user )
    discuss_tasks.each{|task| task.trigger_transition("complete", by_user) }
  end

  def start
    update_attribute(:started, true)
  end

  def add_task(task_definition)
    task = Task.new

    task.task_definition_id = @task_definition.id
    task.project_id         = project.id
    task.task_status_id     = 1
    task.awaiting_signoff   = false

    task.save
  end

  def student
    unit_role.user
  end

  def main_tutor
    unit_role.tutorial.tutor unless unit_role.tutorial.nil?
  end

  def user_role(user)
    if user == student then :student
    elsif user == main_tutor then :tutor
    elsif self.unit.tutors.where(id: user.id).count != 0 then :tutor
    else nil
    end
  end

  def active?
    unit.active
  end

  def reference_date
    if application_reference_date > unit.end_date
      unit.end_date
    else
      application_reference_date
    end
  end

  def assigned_tasks
    required_tasks
  end

  def required_tasks
    tasks.select{|task| task.task_definition.required? }
  end

  def optional_tasks
    tasks.select{|task| !task.task_definition.required? }
  end

  def progress
    self[:progress].to_sym
  end

  def progress=(value)
    self[:progress] = value.to_s
  end

  def status
    self[:status].to_sym
  end

  def status=(value)
    self[:status] = value.to_s
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
    date_progress = unit.start_date

    progress_points.each do |date, weight|
      break if weight > units_completed
      date_progress = date
    end

    (date_progress - reference_date).to_i / 1.day
  end

  def progress_points
    date_accumulated_weight_map = {}

    assigned_tasks.sort{|a, b| a.task_definition.target_date <=>  b.task_definition.target_date}.each do |project_task|
      date_accumulated_weight_map[project_task.task_definition.target_date] = assigned_tasks.select{|task|
        task.task_definition.target_date <= project_task.task_definition.target_date
      }.map{|task| task.task_definition.weighting.to_f}.inject(:+)
    end

    date_accumulated_weight_map
  end

  #
  # Calculate and return the burndown chart data
  # returns four lines:
  # - projected based on previous work marked as at least "ready to assessess"
  # - target based on task definitions
  # - done based on work marked as at least "ready to assess"
  # - complete based on work signed off as complete
  def burndown_chart_data
    # Create buckets by week
    result = [ ]

    # Get the weeks between start and end date as an array
    dates = unit.start_date.to_date.step(unit.end_date.to_date + 1.week, step=7).to_a

    # Setup the dictionaries to contain the keys and values
    # key = series name
    # values = array of [ x, y ] values
    projected_results = { key: "Projected", values: [] }
    target_task_results = { key: "Target", values: [] }
    done_task_results = { key: "Complete", values: [] }
    complete_task_results = { key: "Signed Off", values: [] }

    # get total value of all tasks assigned to this project
    total = assigned_tasks.map{|task| task.task_definition.weighting.to_f}.inject(:+)

    #last done task date
    if ready_or_complete_tasks.empty?
      last_target_date = unit.start_date
    else
      last_target_date = ready_or_complete_tasks.sort{|a,b| a.task_definition.target_date <=>  b.task_definition.target_date }.last.task_definition.target_date
    end

    # Get the target task from the unit's task definitions
    target_tasks = unit.task_definitions.select{|task_def| task_def.required}

    # today is used to determine when to stop adding done tasks
    today = reference_date

    # Get the tasks currently marked as done (or ready to mark)
    done_tasks = ready_or_complete_tasks

    # use weekly completion rate to determine projected progress
    completion_rate = weekly_completion_rate
    projected_remaining = total

    # Track which values to add
    add_projected = true
    add_done = true

    # Iterate over the dates
    dates.each { |date|
      # get the target values - those from the task definitions
      target_val = [ date.to_datetime.to_i, 
          target_tasks.select{|task_def| task_def.target_date > date}.map{|task_def| task_def.weighting.to_f}.inject(:+)
        ]
      # get the done values - those done up to today, or the end of the unit
      done_val = [ date.to_datetime.to_i, 
          done_tasks.select{|task| (not task.completion_date.nil?) and task.completion_date <= date}.map{|task| task.task_definition.weighting.to_f}.inject(:+) 
        ]
      # get the completed values - those signed off
      complete_val = [ date.to_datetime.to_i, 
          completed_tasks.select{|task| task.completion_date <= date}.map{|task| task.task_definition.weighting.to_f}.inject(:+) 
        ]
      # projected value is based on amount done
      projected_val = [ date.to_datetime.to_i, projected_remaining / total ]

      # add one week's worth of completion data
      projected_remaining -= completion_rate

      # if no target value then value is 0 and so will all future weeks be... otherwise its the %remaining
      if target_val[1].nil? then  target_val[1] = 0 else target_val[1] /= total end
      # if no done value then value is 100%, otherwise remaining is the total - %done
      if done_val[1].nil?       then  done_val[1] = 1       else done_val[1] = (total - done_val[1]) / total end
      if complete_val[1].nil?   then  complete_val[1] = 1   else complete_val[1] = (total - complete_val[1]) / total end
      # ensure projected remaining is never negative
      if projected_val[1] < 0 then projected_val[1] = 0 end

      # always add target values - ensures whole range shown
      target_task_results[:values].push target_val
      # add done and projected if appropriate
      if add_done
        done_task_results[:values].push done_val 
        complete_task_results[:values].push complete_val 
      end
      if add_projected then projected_results[:values].push projected_val end

      # stop adding the done tasks once past date - (add once for tasks done this week, hence after adding)
      if add_done and date > today then add_done = false end
      # stop adding projected values once projected is complete
      if add_projected and projected_val[1] <= 0 then add_projected = false end
    }    

    result.push(projected_results)
    result.push(target_task_results)
    result.push(done_task_results)
    result.push(complete_task_results)

    result
  end

  def projected_end_date
    return unit.end_date if rate_of_completion == 0.0
    (remaining_tasks_weight / rate_of_completion).ceil.days.since reference_date
  end

  def weeks_elapsed(date=nil)
    (days_elapsed(date) / 7.0).ceil
  end

  def days_elapsed(date=nil)
    date ||= reference_date
    (date - unit.start_date).to_i / 1.day
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

  def weekly_completion_rate(date=nil)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if ready_or_complete_tasks.empty?
    date ||= reference_date

    weeks = weeks_elapsed(date)
    # Ensure at least one week
    weeks = 1 if weeks < 1

    completed_tasks_weight / weeks.to_f
  end

  def required_task_completion_rate
    remaining_tasks_weight / remaining_days
  end

  def recommended_completed_tasks
    assigned_tasks.select{|task| task.task_definition.target_date < reference_date }
  end

  def completed_tasks
    assigned_tasks.select{|task| task.complete? }
  end

  def ready_or_complete_tasks
    assigned_tasks.select{|task| task.ready_or_complete? }
  end

  def discuss_tasks
    assigned_tasks.select{|task| task.discuss? }
  end

  def partially_completed_tasks
    # TODO: Should probably have a better definition
    # of partially complete than just 'fix' tasks
    assigned_tasks.select{|task| task.fix_and_resubmit? || task.fix_and_include? }
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
    incomplete_tasks.empty? ? 0.0 : incomplete_tasks.map{|task| task.task_definition.weighting }.inject(:+)
  end

  #
  # get the weight of all tasks completed or marked as ready to assess
  #
  def completed_tasks_weight
    ready_or_complete_tasks.empty? ? 0.0 : ready_or_complete_tasks.map{|task| task.task_definition.weighting }.inject(:+)
  end

  def partially_completed_tasks_weight
    # Award half for partially completed tasks
    # TODO: Should probably make this a project-by-project option
    partially_complete = partially_completed_tasks
    partially_complete.empty? ? 0.0 : partially_complete.map{|task| task.task_definition.weighting / 2.to_f }.inject(:+)
  end

  def task_units_completed
    completed_tasks_weight + partially_completed_tasks_weight
  end

  def calc_task_stats
    result = {
      not_submitted: 0.0,
      fix_and_include: 0.0,
      redo: 0.0,
      need_help: 0.0,
      working_on_it: 0.0,
      fix_and_resubmit: 0.0,
      ready_to_mark: 0.0,
      discuss: 0.0,
      complete: 0.0
    }

    total = total_task_weight
    assigned_tasks.each { |task| result[task.status] += task.task_definition.weighting }
    result.each { |key, value| if result[key] < 0.01 then result[key] = 0.0 else result[key] = (value / total).signif(2) end }
    
    total = 0.0
    result.each { |key, value| total += value }

    if total != 1.0
      dif = 1.0 - total
      result.each { |key, value| 
        if value > 0.0
          result[key] = (result[key] + dif).signif(2) 
          break
        end 
      }
    end

    self.task_stats = "#{result[:not_submitted]}|#{result[:fix_and_include]}|#{result[:redo]}|#{result[:need_help]}|#{result[:working_on_it]}|#{result[:fix_and_resubmit]}|#{result[:ready_to_mark]}|#{result[:discuss]}|#{result[:complete]}"
    save
    self.task_stats
  end

  def total_task_weight
    assigned_tasks.map{|task| task.task_definition.weighting }.inject(:+)
  end

  def currently_due_tasks
    assigned_tasks.select{|task| task.currently_due? }
  end

  def overdue_tasks
    assigned_tasks.select{|task| task.overdue? }
  end

  def remaining_days
    (unit.end_date - reference_date).to_i / 1.day
  end

  def in_progress?
    commenced? && !concluded?
  end

  def commenced?
    application_reference_date >= unit.start_date
  end

  def concluded?
    application_reference_date > unit.end_date
  end

  def has_optional_tasks?
    tasks.any?{|task| !task.task_definition.required }
  end

  def last_task_completed
    completed_tasks.sort{|a, b| a.completion_date <=> b.completion_date }.last
  end

  def self.status_distribution(projects)
    project_count = projects.length

    status_totals = {
      ahead: 0,
      on_track: 0,
      behind: 0,
      danger: 0,
      doomed: 0,
      not_started: 0,
      total: 0
    }

    projects.each do |project|
      if project.started?
        status_totals[project.progress] += 1
      else
        status_totals[:not_started] += 1
      end
    end

    status_totals[:total] = project_count

    Hash[status_totals.sort_by{|status, count| count }]
  end

  def task_completion_csv(options={})
    [
      user.username,
      user.name,
      student.tutorial.tutor.name
    ] + tasks.map{|task| task.task_status.name }
  end
end
