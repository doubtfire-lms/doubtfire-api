module ProjectTemplatesHelper

	# Gets a list of the convenors involved in a project as a string of form "Convenor 1, Convenor 2, ..."
	def get_convenors_string(project_template_id)

		# Get all users who are convenors for the specified project
		convenors = User.joins(:project_administrators => :project_template)
		    			.where(:project_administrators => {:project_template_id => project_template_id})
		
		# Concatenate their names into a string
		convenors_string = ""
		convenors.each do |convenor|
			convenors_string += convenor.full_name + ", "
		end

		# Return the string without the last comma and space
		convenors_string[0..-3]
	end
end