module TasksHelper
  def label_for_task(task)
    # TODO: Replace strings with constants
    # TODO: Determining the colour/urgency of something
    # is repetitive. Refactoring it out of here.
    case task.status
    when :not_submitted
      if task.overdue?
        if task.long_overdue?
          "label label-important" # Show a more urgent label if the task is long overdue
        else
          "label label-warning" # Just show a warning label if task is overdue
        end
      else
        "label" # Just return standard if there is nothing exceptional about the task's status
      end
    when :needs_fixing
      "label label-info" # Info for needs fixing
    when :complete
      "label label-success" # Success if the task is complete
    end
  end

  def label_text_for_task(task)
    task.task_status.name
  end

  def task_status(task)
    if task.complete?
      raw "<p class=\"task-status\">Complete</p>"
    else
      if task.awaiting_signoff?
        raw "<p class=\"task-status\">Awaiting Signoff</p>"
      else
        raw "<p class=\"task-status\">Not Submitted</p>"
      end
    end
  end

  def task_submission_vs_time(task)
    # Task is complete, so we don't really care
    # when
    return raw "<p class=\"task-submission-vs-time\"></p>" if task.complete?

    if task.overdue?
      weeks_overdue = task.weeks_overdue

      if weeks_overdue > 0
        raw "<p class=\"task-submission-vs-time\">Overdue (#{pluralize(weeks_overdue, 'week')})</p>"
      else
        raw "<p class=\"task-submission-vs-time\">Due this week</p>"
      end
    else
      if task.weeks_until_due > 0
        raw "<p class=\"task-submission-vs-time\">Due in #{pluralize(task.weeks_until_due, 'weeks')}</p>"
      else
        raw "<p class=\"task-submission-vs-time\">Due this week</p>"
      end
    end
  end

  def status_badge_for_task(task)
    raw "<span class=\"task-status-label #{label_for_task(task)}\">#{label_text_for_task(task)}</span>"
  end

  def awaiting_signoff_badge_for_task(task)
    raw "<span class=\"task-awaiting-signoff-label label label-info\">Awaiting Sign-off</span>"
  end
end