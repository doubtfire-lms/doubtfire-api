module TutorProjectsHelper
  def unmarked_project_tasks(tutor_project_template, tutor)
    tutors_teams    = Team.where(:project_template_id => tutor_project_template.id, :user_id => tutor.id)
    tutors_projects = Project.includes(:tasks).find(
      TeamMembership.where(:team_id => [tutors_teams.map{|team| team.id}])
      .map{|membership| membership.project_id }
    )

    tutors_projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff? }
  end

  def user_task_map(tasks)
    user_tasks      = {}

    tasks.each do |task|
      user_for_task = task.project.team_membership.user

      user_tasks[user_for_task] ||= []
      user_tasks[user_for_task] << task
    end

    user_tasks
  end

  def unmarked_tasks(projects)
    projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff? }
  end

  def user_unmarked_tasks(projects)
    user_task_map(unmarked_tasks(projects))
  end

  def needing_help_tasks(projects)
    need_help_status = TaskStatus.where(:name => "Need Help").first
    projects.map{|project| project.tasks }.flatten.select{|task| task.task_status.id == need_help_status.id }
  end

  def user_needing_help_tasks(projects)
    user_task_map(needing_help_tasks(projects))
  end

  def working_on_it_tasks(projects)
    working_on_it_status = TaskStatus.where(:name => "Working On It").first
    projects.map{|project| project.tasks }.flatten.select{|task| task.task_status.id == working_on_it_status.id }
  end

  def user_working_on_it_tasks(projects)
    user_task_map(working_on_it_tasks(projects))
  end

  def tasks_progress_bar(project, student, mode=:progress)
    tasks = project.assigned_tasks

    progress = project.relative_progress

    raw(tasks.each_with_index.map{|task, i|
      task_class  = nil

      if task.complete?
        progress_suffix = progress.to_s.gsub("_", "-")
        progress_class  = "progress-#{progress_suffix}"
        action_class    = "action-complete"
        status_text     = "Complete"
      elsif task.awaiting_signoff?
        progress_class  = "action-awaiting-signoff"
        action_class    = "action-awaiting-signoff"
        status_text     = "Awaiting Signoff"
      elsif task.needs_fixing?
        progress_class  = "action-incomplete"
        action_class    = "action-needs-fixing"
        status_text     = "Needs Fixing"
      elsif task.need_help?
        progress_class  = "action-incomplete"
        action_class    = "action-need-help"
        status_text     = "Need Some Help"
      elsif task.working_on_it?
        progress_class  = "action-incomplete"
        action_class    = "action-working-on-it"
        status_text     = "Working On It"
      else
        progress_class  = "action-incomplete"
        action_class    = "action-incomplete"
        status_text     = "Incomplete"
      end

      status_html = "<strong>Status:</strong> #{status_text}<br/><br/>"
      description_text = (task.task_template.description.nil? or task.task_template.description == "NULL") ? "(No description provided)" : task.task_template.description

      active_class = mode == :progress ? progress_class : action_class

      link_to(
        "#{i + 1}",
        tutor_project_student_path(project, student),
        :rel => "popover",
        :class => "task-progress-item #{active_class}",
        "data-progress-class" => progress_class,
        "data-action-class"   => action_class,
        "data-original-title" => "#{task.task_template.name}",
        "data-content"        => "#{status_html} #{description_text}"
      )
    }.join("\n"))
  end
end