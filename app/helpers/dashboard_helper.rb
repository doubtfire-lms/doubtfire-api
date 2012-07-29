module DashboardHelper
  def project_health(project)
    tasks = project.tasks
    completed_tasks         = tasks.select{|task| task.task_status.name == "Complete" }
    completed_tasks_weight  = completed_tasks.map{|task| task.task_template.weight }.inject(:+)
    total_task_weight       = tasks.map{|task| task.task_template.weight }.inject(:+)
  end

  def ahead_of_schedule_text
    "You're ahead of schedule. Keep up the great work!"
  end

  def falling_behind_text
    "It looks like you're falling behind. Time to get some work done."
  end

  def status_badge(project)
    if !project.has_commenced?
      raw("<span class=\"label\">Not Started</span>")
    else
      raw("<span class=\"label label-success\">Ahead</span>")
    end
  end

  def not_going_to_finish_in_time
    "At this rate, you're not going to complete the remaining tasks in time"
  end

  def early_finish
    "At this rate, your set to finish one week earlier than expected"
  end

  def will_complete_based_on_velocity(project)
    complete_based_on_velocity = early_finish

    if !project.has_commenced? or project.has_concluded?
      nil
    else
      raw("<p>#{complete_based_on_velocity}</p>")
    end
  end

  def guidance_based_on_velocity(project)
    if !project.has_commenced?
      raw("<p>To achieve the best result possible for this subject, ensure that you are getting tasks marked off regularly and often.</p>")
    else
      raw("<p>If you haven't already, you should consider <a href=\"#\">going the extra mile for a D or HD</a></p>")
    end
  end

  def projected_date_of_completion_vs_deadline(project)
    deadline = project.project_template.end_date 

    if !project.has_commenced?
      raw("<p>This project is yet commence. Make sure you set a good pace early on to avoid falling behind.</p>")
    elsif project.has_concluded?
      raw("<p>Project has concluded</p>")
    else
      project_date_string = deadline.strftime("#{deadline.day.ordinalize} of %B")
      project_date_of_completion_text = "Projected end date is the <strong>#{project_date_string}</strong>"

      deadline_date_string = deadline.strftime("#{deadline.day.ordinalize} of %B")
      deadline_text = "<span style=\"color: #AAAAAA\">(deadline is the #{deadline_date_string})</span>"

      raw("<p>#{project_date_of_completion_text} #{deadline_text}</p>")
    end 
  end

  def project_status_summary(project)
    if !project.has_commenced?
    status_summary = "This project has not commenced. Best of luck for the upcoming start of the project!"
    elsif project.has_concluded?
      status_summary = "This project has concluded. Congratulations on the great result!"
    else
      status_summary = ahead_of_schedule_text
    end
    raw("<p>#{status_summary}</p>")
  end
end