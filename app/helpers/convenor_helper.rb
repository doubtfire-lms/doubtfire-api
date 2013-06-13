module ConvenorHelper

	def no_active_projects?
		units = @user.project_convenors.map{|pm| pm.unit }
		units.empty?
	end

	def doomface_for(status)
		case status
			when :ahead then image_tag "doomface_god.gif"
			when :on_track then image_tag "doomface_damage0.gif"
			when :behind then image_tag "doomface_damage2.gif"
			when :danger then image_tag "doomface_damage4.gif"
			when :doomed then image_tag "doomface_dead.gif"
		end		
	end

end
