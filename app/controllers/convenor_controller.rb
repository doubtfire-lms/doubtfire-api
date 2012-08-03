class ConvenorController < ApplicationController

	before_filter :authenticate_user!
	before_filter :load_current_user

	def index
		@project_templates = ProjectTemplate.joins(:project_convenors).where(:project_convenors => {:user_id => current_user.id})
	end

	def load_current_user
  	@user = current_user
	end

end
