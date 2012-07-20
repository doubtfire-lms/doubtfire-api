class ConvenorProjectController < ApplicationController

	def index
		@project_template = ProjectTemplate.find(params[:id])
	end

end
