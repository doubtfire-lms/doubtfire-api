module DashboardHelper
  def status_badge(status)
    case status
      when :completed     then content_tag(:span, completed_badge,      class: "status-badge label label-success")
      when :not_completed then content_tag(:span, not_completed_badge,  class: "status-badge label label-important")
      when :not_commenced then content_tag(:span, "Not Commenced",      class: "status-badge label")
      when :not_started   then content_tag(:span, "Not Commenced",      class: "status-badge label")
      when :in_progress   then content_tag(:span, "In Progress",        class: "status-badge label")
      else content_tag(:span, "Unknown Progress", class: "status-badge label")
    end
  end

  def progress_badge(progress)
    case progress
      when :ahead         then content_tag(:span, "Going Well",       class: "status-badge label label-success")
      when :on_track      then content_tag(:span, "Progressing",      class: "status-badge label label-info")
      when :behind        then content_tag(:span, "Need to Catch Up", class: "status-badge label label-warning")
      when :danger        then content_tag(:span, "Seek Help",        class: "status-badge label label-important")
      when :doomed        then content_tag(:span, "Talk to Convenor", class: "status-badge label label-inverse")
      else content_tag(:span, "Unknown Progress", class: "status-badge label")
    end
  end

  def completed_badge
    raw('Completed <i class="icon-ok"></i>')
  end

  def not_completed_badge
    raw('Not Completed <i class="icon-remove"></i>')
  end  

  def will_complete_based_on_velocity(project)
    if project.in_progress?

      if project.completed?
        completion_date = project.last_task_completed.completion_date.to_time

        days_left_before_deadline  = ((project.project_template.end_date - completion_date).to_i / 1.day)
        
        if days_left_before_deadline < 7
          if days_left_before_deadline == 0
            complete_based_on_velocity = "You finished right on the target date."
          elsif days_left_before_deadline == 1
            complete_based_on_velocity = "You finished a day before the target date."
          else
            complete_based_on_velocity = "You finished #{days_left_before_deadline} days before the target date."
          end
        else
          weeks_left_before_deadline = (days_left_before_deadline / 7.to_f).ceil

          if weeks_left_before_deadline == 1
            complete_based_on_velocity = "You finished a week before the target date."
          else
            complete_based_on_velocity = "You finished #{weeks_left_before_deadline} weeks before the target date."
          end
        end
      else
        days_left_before_deadline  = ((project.projected_end_date - project.project_template.end_date).to_i / 1.day)
        weeks_left_before_deadline = -(days_left_before_deadline / 7.to_f).ceil

        if weeks_left_before_deadline > 0
          if weeks_left_before_deadline == 1
            complete_based_on_velocity = "At this rate, you're set to finish #{weeks_left_before_deadline.abs} weeks before the deadline"
          else
            complete_based_on_velocity = "At this rate, you're set to finish a week before the deadline."
          end
        elsif weeks_left_before_deadline < 0
          if weeks_left_before_deadline.abs == 1
            complete_based_on_velocity = "At this rate, you're set to finish a week after the deadline."
          else
            complete_based_on_velocity = "At this rate, you're set to finish #{weeks_left_before_deadline.abs} weeks after the deadline"
          end
        else
          complete_based_on_velocity = "At this rate, you're set to finish right on the deadline."
        end
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
    tasks = project.assigned_tasks
    completed_tasks         = tasks.select{|task| task.task_status.name == "Complete" }
    completed_task_count    = completed_tasks.size
    total_task_count        = tasks.size

    if project.concluded?
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
      if project.completed?
        raw(
          [
            "<p>",
              "You've successfully completed all <strong>#{total_task_count} tasks</strong>. Well done!",
            "</p>"
          ].join("\n")
        )
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
  end

  def health_label(project)
    raw(["<div class=\"health-label\">",
          "\t<span class=\"statistical-figure\">#{(project.health * 100).floor}%</span>",
          "\t<p class=\"statistical-figure-subtext\">Health</p>",
        "</div>"].join("\n"))
  end

  def guidance_based_on_velocity(project)
    if !project.commenced?
      raw("<p>To achieve the best result possible for this subject, ensure that you are getting tasks marked off regularly and often.</p>")
    else
      if project.completed?
        # TODO: Suggest completing optional tasks if all required tasks are finished.
      else
        case project.progress
        when :ahead
          raw("<p>If you haven't already, you should consider <a href=\"#\">going the extra mile for a D or HD</a></p>")
        end
      end
    end
  end

  def projected_date_of_completion_vs_deadline(project)
    start_date  = project.project_template.start_date
    deadline    = project.project_template.end_date

    if !project.commenced?
      start_date_string = start_date.strftime("#{start_date.day.ordinalize} of %B")
      raw("<p>This project commences on the <strong>#{start_date_string}</strong>. Make sure you set a good pace early on to avoid falling behind.</p>")
    elsif project.concluded?
      raw("<p>This project ended on the #{deadline.strftime("#{deadline.day.ordinalize} of %B")}</p>")
    else
      if project.completed?
        completion_date = project.last_task_completed.completion_date
        completion_date_string = completion_date.strftime("#{completion_date.day.ordinalize} of %B")
        raw("<p>This project was completed on the #{completion_date_string}.</p>")
      else
        projected_end_date                = project.projected_end_date

        if projected_end_date.year == deadline.year
          projected_date_string             = projected_end_date.strftime("#{projected_end_date.day.ordinalize} of %B")
          deadline_date_string              = deadline.strftime("#{deadline.day.ordinalize} of %B")
        else
          projected_date_string             = projected_end_date.strftime("#{projected_end_date.day.ordinalize} of %B, %Y")
          deadline_date_string              = deadline.strftime("#{deadline.day.ordinalize} of %B, %Y")
        end

        projected_date_of_completion_text = "Projected end date is the <strong>#{projected_date_string}</strong>"
        deadline_text = "<span style=\"color: #AAAAAA\">(deadline is the #{deadline_date_string})</span>"

        raw("<p>#{projected_date_of_completion_text} #{deadline_text}</p>")
      end
    end 
  end

  def project_status_summary(project)
    status_summary = if !project.commenced?
      "This project has not commenced. Best of luck for the upcoming start of the project!"
    elsif project.concluded?
      if project.completed? 
        "This project has concluded. Congratulations on completing all of the allocated tasks!"
      else
        "This project has concluded. Unfortunately you did not complete all of the set tasks."
      end
    else
      if project.completed?
        project_complete_text
      else
        status_text(project.status)
      end
    end

    raw("<p>#{status_summary}</p>")
  end

  def status_text(status)
    case status
      when :ahead       then ahead_of_schedule_text
      when :on_track    then on_track_text
      when :behind      then falling_behind_text
      when :danger      then in_danger_text
      when :doomed      then doomed_text
      when :not_started then not_started_text
    end
  end

  def rate_of_completion(project)
    rate_of_completion_string             = "%5.1f" % (project.rate_of_completion * 7)        # 7 days in a week

    if project.completed?
      completion_date = project.last_task_completed.completion_date.to_time
      rate_per_week = project.rate_of_completion(completion_date) * 7

      raw(
        ["<p>",
          "\tYour rate of completion throughout the project was #{rate_of_completion_string} task points per week.",
        "</p>"].join("\n")
      )
    else
      required_task_completion_rate_string  = "%5.1f" % (project.required_task_completion_rate * 7) # 7 days in a week
      raw(
        ["<p>",
          "\tCurrent rate of completion is #{rate_of_completion_string} task points per week",
          "\t<span class=\"supplementary-text\">(required rate to finish on time is #{required_task_completion_rate_string} tasks points per week)</span>",
        "</p>"].join("\n")
      )
    end
  end

  def class_for_project_status(project)
    class_for_project = if project.commenced?
      if project.started?
        project.progress
      else
        :not_started
      end
    else
      :not_commenced
    end.to_s.gsub("_", "-")
  end

  def project_progress_bar(project)
    raw ["<div class=\"progress progress-#{class_for_project_status(project)}\">",
          "\t<div class=\"bar\" style=\"width: #{project.percentage_complete}%;\"></div>",
        '</div>'].join("\n")
  end

  def not_started_text
    "You've not yet started this project. Start completing some tasks to improve your progress."
  end

  def ahead_of_schedule_text
    "You're ahead of schedule. Keep up the great work!"
  end

  def project_complete_text
    "You've completed this project before the end of the allocated time period. Well done!"
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
end