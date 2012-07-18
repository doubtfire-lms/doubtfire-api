module DashboardHelper
  def ahead_of_schedule_text
    "You're ahead of schedule. Keep up the great work!"
  end

  def falling_behind_text
    "It looks like you're falling behind. Time to get some work done."
  end

  def status_badge(health)
    raw("<span class=\"label label-success\">Ahead</span>")
  end

  def not_going_to_finish_in_time
    "At this rate, you're not going to complete the remaining tasks in time"
  end

  def early_finish
    "At this rate, your set to finish one week earlier than expected"
  end

  def will_complete_based_on_velocity
    complete_based_on_velocity = early_finish
    raw("<p>#{complete_based_on_velocity}</p>")
  end

  def guidance_based_on_velocity
    raw("<p>If you haven't already, you should consider <a href=\"#\">going the extra mile for a D or HD</a></p>")
  end

  def projected_date_of_completion_vs_deadline(project)
    deadline = project.project_template.end_date 

    project_date_string = deadline.strftime("#{deadline.day.ordinalize} of %B")
    project_date_of_completion_text = "Projected end date is the <strong>#{project_date_string}</strong>"

    deadline_date_string = deadline.strftime("#{deadline.day.ordinalize} of %B")
    deadline_text = "<span style=\"color: #AAAAAA\">(deadline is the #{deadline_date_string})</span>"

    raw("<p>#{project_date_of_completion_text} #{deadline_text}</p>")
  end

  def project_status_summary(health)
    status_summary = ahead_of_schedule_text
    raw("<p>#{status_summary}</p>")
  end
end