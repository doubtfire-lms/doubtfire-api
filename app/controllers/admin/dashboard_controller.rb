class Admin::DashboardController < ApplicationController
	
	def index
		@units = Unit.all
		@users = User.all
	end
end