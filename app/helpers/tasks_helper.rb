module TasksHelper
  def label_for_task(task)
    # TODO: Replace strings with constants
    # TODO: Determining the colour/urgency of something
    # is repetitive. Refactoring it out of here.
    case task.status
    when :incomplete
      if task.overdue?
        if task.long_overdue?
          "label-important" # Show a more urgent label if the task is long overdue
        else
          "label-warning" # Just show a warning label if task is overdue
        end
      else
        nil # Just return nil if there is nothing exceptional about the task's status
      end
    when :complete
      "label-success" # Success if the task is complete
    end
  end

  def badge_for_task(task)
    label_class_for_task = label_for_task(task)
    raw "<span class=\"label#{label_class_for_task ? "" : " #{label_class_for_task}"}\">#{task.task_status.name}</span>"
  end
end