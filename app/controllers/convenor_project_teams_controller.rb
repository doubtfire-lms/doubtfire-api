class ConvenorProjectTeamsController < ApplicationController
  def index
    @convenor_projects = Unit.joins(:project_convenors)
                                        .where(project_convenors: {user_id: current_user.id})

    @unit = Unit.includes(:task_definitions).find(params[:id])
    
    @projects = Project.includes({
                  team_membership: [:user, :team],
                  tasks: [:task_definition]
                  }, :unit
                )
                .where(unit_id: params[:id])

    @projects.sort!{|a,b| a.team_membership.user.name <=> b.team_membership.user.name }

    @project_teams = @projects.map {|project|
      project.team_membership.team
    }.uniq
  end

  def show
    @convenor_projects = Unit.joins(:project_convenors)
                                        .where(project_convenors: {user_id: current_user.id})
    
    @unit = Unit.find(params[:unit_id])
    authorize! :read, @unit, :message => "You are not authorised to view Unit ##{@unit.id}"
    
    @team             = Team.find(params[:team_id])
  end
end
