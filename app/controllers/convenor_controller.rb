class ConvenorController < ApplicationController

	before_filter :authenticate_user!
	before_filter :load_current_user

	def index
		@project_templates = ProjectTemplate.joins(:project_administrators).where(:project_administrators => {:user_id => current_user.id})
	end

	def load_current_user
  	@user = current_user
	end

end
