class ConvenorProjectsController < ApplicationController
	def show
		@project_template = ProjectTemplate.includes(:task_templates).find(params[:id])
    
    @projects = Project.includes(team_membership:
                  [
                    {
                      project: [
                      { 
                        tasks: :task_template
                      }
                    ]},
                    :team,
                    :user
                  ]
                )
                .where(project_template_id: params[:id])

    @projects.sort!{|a,b| a.team_membership.user.name <=> b.team_membership.user.name }

    @project_teams = @projects.map {|project|
      project.team_membership.team
    }.uniq
	end
end