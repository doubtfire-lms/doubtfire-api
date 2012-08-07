class SuperuserController < ApplicationController

	before_filter :authenticate_user!
	before_filter :load_current_user

	def index
		@project_templates = ProjectTemplate.all
		@users = User.where("system_role != 'superuser'")
	end

	private

	def load_current_user
		@user = current_user
	end

end
