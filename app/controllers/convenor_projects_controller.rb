class ConvenorProjectsController < ApplicationController
	def show
		@project_template = ProjectTemplate.find(params[:id])
    
		@project_users = User.joins(:team_memberships => {:project => :project_template})
                      .where(:projects => {:project_template_id => params[:id]})
                      .order(:first_name)

    @project_teams = @project_template.teams
	end
end