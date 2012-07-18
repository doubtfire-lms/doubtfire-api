class AdministrationController < ApplicationController

	before_filter :authenticate_user!
	before_filter :load_current_user

	def index
		@users = User.all
		@projects = Project.all
	end

	private

	def load_current_user
		@user = current_user
	end

end
