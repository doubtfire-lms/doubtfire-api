class ConvenorProjectController < ApplicationController
	def index
		@project_template = ProjectTemplate.find(params[:id])
		@project_users = User.joins(:team_memberships => {:project => :project_template})
							 .where(:projects => {:project_template_id => params[:id]})
	end
end
