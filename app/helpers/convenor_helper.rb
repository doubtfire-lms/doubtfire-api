module ConvenorHelper
	def no_active_projects?
		units = @user.project_convenors.map{|pm| pm.unit }
		units.empty?
	end
end