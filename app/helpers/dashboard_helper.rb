module DashboardHelper
  def status_badge(project)
    if !project.has_commenced?
      raw("<span class=\"label\">Not Started</span>")
    elsif project.has_concluded?
      if project.completed?
        raw("<span class=\"label label-success\">Completed</span>")
      else
        raw("<span class=\"label label-important\">Not Completed</span>")
      end
    else
      progress = project.relative_progress

      case progress
        when :ahead     then raw("<span class=\"label label-success\">Ahead</span>")
        when :on_track  then raw("<span class=\"label label-info\">On Track</span>")
        when :behind    then raw("<span class=\"label label-warning\">Behind</span>")
        when :danger    then raw("<span class=\"label label-important\">Danger</span>")
        when :doomed    then raw("<span class=\"label label-inverse\">Doomed</span>")
      end
    end
  end

  def will_complete_based_on_velocity(project)
    if project.in_progress?
      days_left_before_deadline  = ((project.projected_end_date - project.project_template.end_date).to_i / 1.day)
      weeks_left_before_deadline = -(days_left_before_deadline / 7.to_f).ceil

      if weeks_left_before_deadline > 0
        complete_based_on_velocity = "At this rate, you're set to finish #{weeks_left_before_deadline.abs} weeks before the deadline"
      elsif weeks_left_before_deadline < 0
        complete_based_on_velocity = "At this rate, you're set to finish #{weeks_left_before_deadline.abs} weeks after the deadline"
      else
        complete_based_on_velocity = "At this rate, you're set to finish right on the deadline"
      end

      raw("<p>#{complete_based_on_velocity}</p>")
    else
      nil
    end
  end

  def early_finish
    "At this rate, your set to finish one week earlier than expected"
  end

  def not_going_to_finish_in_time
    "At this rate, you're not going to complete the remaining tasks in time"
  end

  def task_completion(project)
    tasks = project.tasks
    completed_tasks         = tasks.select{|task| task.task_status.name == "Complete" }
    completed_task_count    = completed_tasks.size
    total_task_count        = tasks.size

    if project.has_concluded?
      if project.completed?
        raw(
          [
            "<p>",
              "You successfully completed all <strong>#{total_task_count} tasks</strong>. Well done!",
            "</p>"
          ].join("\n")
        )
      else
        raw(
          [
            "<p>",
              "You were unable to complete <strong>#{total_task_count - completed_task_count} tasks</strong>",
              "of the total of <strong>#{total_task_count} tasks</strong> for this project.",
            "</p>"
          ].join("\n")
        )
      end
    else
      raw(
        [
          "<p>",
            "You have <strong>#{total_task_count - completed_task_count} tasks</strong> remaining",
            "(<span class=\"supplementary-text\">#{completed_task_count}",
            "out of #{total_task_count}</strong> tasks completed)</span>",
          "</p>"
        ].join("\n")
      )
    end
  end

  def health_label(project)
    raw(["<div class=\"health-label\">",
          "\t<span class=\"statistical-figure\">#{(project.health * 100).floor}%</span>",
          "\t<p class=\"statistical-figure-subtext\">Health</p>",
        "</div>"].join("\n"))
  end

  def guidance_based_on_velocity(project)
    if !project.has_commenced?
      raw("<p>To achieve the best result possible for this subject, ensure that you are getting tasks marked off regularly and often.</p>")
    else
      case project.relative_progress
      when :ahead
        raw("<p>If you haven't already, you should consider <a href=\"#\">going the extra mile for a D or HD</a></p>")
      end
    end
  end

  def projected_date_of_completion_vs_deadline(project)
    start_date  = project.project_template.start_date
    deadline    = project.project_template.end_date

    if !project.has_commenced?
      start_date_string = start_date.strftime("#{start_date.day.ordinalize} of %B")
      raw("<p>This project commences on the <strong>#{start_date_string}</strong>. Make sure you set a good pace early on to avoid falling behind.</p>")
    elsif project.has_concluded?
      raw("<p>This project ended on the #{deadline.strftime("#{deadline.day.ordinalize} of %B")}</p>")
    else
      projected_end_date                = project.projected_end_date
      projected_date_string             = projected_end_date.strftime("#{projected_end_date.day.ordinalize} of %B")
      projected_date_of_completion_text = "Projected end date is the <strong>#{projected_date_string}</strong>"

      deadline_date_string = deadline.strftime("#{deadline.day.ordinalize} of %B")
      deadline_text = "<span style=\"color: #AAAAAA\">(deadline is the #{deadline_date_string})</span>"

      raw("<p>#{projected_date_of_completion_text} #{deadline_text}</p>")
    end 
  end

  def project_status_summary(project)
    if !project.has_commenced?
    status_summary = "This project has not commenced. Best of luck for the upcoming start of the project!"
    elsif project.has_concluded?
      if project.completed? 
        status_summary = "This project has concluded. Congratulations on completing all of the allocated tasks!"
      else
        status_summary = "This project has concluded. Unfortunately you did not complete all of the set tasks."
      end
    else
      project_progress = project.relative_progress

      status_summary = case project_progress
        when :ahead     then ahead_of_schedule_text
        when :on_track  then on_track_text
        when :behind    then falling_behind_text
        when :danger    then in_danger_text
        when :doomed    then doomed_text
      end
    end
    raw("<p>#{status_summary}</p>")
  end

  def ahead_of_schedule_text
    "You're ahead of schedule. Keep up the great work!"
  end

  def on_track_text
    "You're on track at the moment. Make sure you keep up the pace so you don't fall behind."
  end

  def falling_behind_text
    "It looks like you're falling behind. Time to get some work done."
  end

  def in_danger_text
    "You're way behind. Get some tasks done as soon as possible or it may be too late."
  end

  def doomed_text
    "You're in serious trouble. Talk to the convenor about your remaining options in this subject."
  end

  def rate_of_completion(project)
    rate_of_completion_string             = "%5.1f" % (project.rate_of_completion * 7)        # 7 days in a week
    required_task_completion_rate_string  = "%5.1f" % (project.required_task_completion_rate * 7) # 7 days in a week
    raw(
        ["<p>",
          "\tCurrent rate of completion is #{rate_of_completion_string} task points per week",
          "\t<span class=\"supplementary-text\">(required rate to finish on time is #{required_task_completion_rate_string} tasks points per week)</span>",
        "</p>"].join("\n")
      )
  end
end