module TutorProjectsHelper
  def unmarked_project_tasks(tutor_project_template, tutor)
    tutors_teams    = Team.where(:project_template_id => tutor_project_template.id, :user_id => tutor.id)
    tutors_projects = Project.includes(:tasks).find(
      TeamMembership.where(:team_id => [tutors_teams.map{|team| team.id}])
      .map{|membership| membership.project_id }
    )

    tutors_projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff? }
  end

  def unmarked_tasks(tutors_projects)
    tutors_projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff? }
  end

  def tasks_progress_bar(project, student)
    tasks = project.assigned_tasks

    progress = project.relative_progress

    raw(tasks.each_with_index.map{|task, i|
      task_class  = nil
      if task.complete?
        task_class  = progress.to_s.gsub("_", "-")
        status_text = "Complete"
      else
        if task.awaiting_signoff?
          task_class = "awaiting-signoff"
          status_text = "Awaiting Signoff"
        elsif task.needs_fixing?
          task_class = "needs-fixing"
          status_text = "Needs Fixing"
        elsif task.need_help?
          task_class = "need-help"
          status_text = "Need Some Help"
        elsif task.working_on_it?
          task_class = "working-on-it"
          status_text = "Working On It"
        else
          task_class = "incomplete-task"
          status_text = "Incomplete"
        end
      end

      status_html = "<strong>Status:</strong> #{status_text}<br/><br/>"
      description_text = (task.task_template.description.nil? or task.task_template.description == "NULL") ? "(No description provided)" : task.task_template.description

      link_to(
        "#{i + 1}",
        tutor_project_student_path(project, student),
        :rel => "popover",
        :class => "task-progress-item progress-#{task_class}",
        "data-original-title" => "#{task.task_template.name}",
        "data-content"        => "#{status_html} #{description_text}"
      )
    }.join("\n"))
  end
end