class ConvenorController < ApplicationController

	before_filter :authenticate_user!
	before_filter :load_current_user

	def index
		@projects = @user.project_administrators.map{|pm| pm.project_template }
	end

  	def load_current_user
    	@user = current_user
  	end

end
