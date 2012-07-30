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
end