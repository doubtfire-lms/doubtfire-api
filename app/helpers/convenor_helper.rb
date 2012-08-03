module ConvenorHelper

	def no_active_projects?
		project_templates = @user.project_convenors.map{|pm| pm.project_template }
		project_templates.empty?
	end

end
