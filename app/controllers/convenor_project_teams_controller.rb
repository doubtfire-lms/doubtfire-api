class ConvenorProjectTeamsController < ApplicationController
  def index
    @convenor_projects = ProjectTemplate.joins(:project_convenors)
                                        .where(project_convenors: {user_id: current_user.id})

    @project_template = ProjectTemplate.includes(:task_templates).find(params[:id])
    
    @projects = Project.includes({
                  team_membership: [:user, :team],
                  tasks: [:task_template]
                  }, :project_template
                )
                .where(project_template_id: params[:id])

    @projects.sort!{|a,b| a.team_membership.user.name <=> b.team_membership.user.name }

    @project_teams = @projects.map {|project|
      project.team_membership.team
    }.uniq
  end

  def show
    @convenor_projects = ProjectTemplate.joins(:project_convenors)
                                        .where(project_convenors: {user_id: current_user.id})
    
    @project_template = ProjectTemplate.find(params[:project_template_id])
    authorize! :read, @project_template, :message => "You are not authorised to view Project Template ##{@project_template.id}"
    
    @team             = Team.find(params[:team_id])
  end
end