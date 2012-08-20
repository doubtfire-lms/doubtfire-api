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

  def task_submission_vs_time_text(task)
    if task.overdue?
      weeks_overdue = task.weeks_overdue

      if weeks_overdue > 0
        raw "Overdue (#{pluralize(weeks_overdue, 'week')})"
      else
        raw "Due this week"
      end
    else
      if task.weeks_until_due > 0
        "Due in #{pluralize(task.weeks_until_due, 'weeks')}"
      else
        raw "Due this week"
      end
    end
  end

  def status_badge_for_task(task)
    raw "<span class=\"task-status-label #{label_for_task(task)}\">#{label_text_for_task(task)}</span>"
  end

  def awaiting_signoff_badge_for_task(task)
    raw "<span class=\"task-awaiting-signoff-label label label-info\">Awaiting Sign-off</span>"
  end

  def task_status_active_button(task)
    button_class  = nil
    button_text   = ""
    button_icon   = nil

    if task.awaiting_signoff?
      button_class  = 'btn-primary'
      button_text   = 'Ready to Mark'
      button_icon   = 'icon-thumbs-up'
    else
      if task.needs_fixing?
        button_class  = 'btn-warning'
        button_text   = 'Needs Fixing'
        button_icon   = 'icon-wrench'
      elsif task.need_help?
        button_class  = 'btn-danger'
        button_text   = 'Need Some Help'
        button_icon   = 'icon-exclamation-sign'
      elsif task.working_on_it?
        button_class  = 'btn-info'
        button_text   = 'Working On It'
        button_icon   = 'icon-bolt'
      elsif task.complete?
        button_class  = 'btn-success'
        button_text   = 'Complete'
        button_icon   = 'icon-ok'
      else
        button_text   = 'Not Ready to Mark'
      end
    end

    raw ["<button class=\"btn #{button_class} status-display-button\">",
            "#{button_text}",
            (button_icon ? "<i class=\"#{button_icon} button-icon\"></i>" : ""),
        '</button>',
        "<button class=\"btn #{button_class} dropdown-toggle\" data-toggle=\"dropdown\">",
          '<span class="caret"></span>',
        '</button>'].join("\n")
  end
end