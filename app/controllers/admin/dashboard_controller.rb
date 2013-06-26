class Admin::DashboardController < ApplicationController
	before_filter :authenticate_user!

	def index
		@units = Unit.all
		@users = User.all
	end
end