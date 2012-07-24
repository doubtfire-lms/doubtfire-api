class ConvenorProjectController < ApplicationController

	def index
		@project_template = ProjectTemplate.find(params[:id])
		@project_users = User.joins(:team_memberships => {:project => :project_template}).where("project_template_id = 1")
	end

end