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
      task_class  = if task.complete?
        progress.to_s.gsub("_", "-")
      else
        task.awaiting_signoff? ? "awaiting-signoff" : "incomplete-task"
      end

      description_text = (task.task_template.description.nil? or task.task_template.description == "NULL") ? "(No description provided)" : task.task_template.description

      link_to(
        "#{i + 1}",
        tutor_project_student_path(project, student),
        :rel => "popover",
        :class => "task-progress-item progress-#{task_class}",
        "data-original-title" => "#{task.task_template.name}",
        "data-content"        => "#{description_text}"
      )
    }.join("\n"))
  end
end