module AuthorisationHelpers

	def authorise? (user, object, action)
		obj_class = object.class

		perms = obj_class.permissions

		role = object.role_for(user)

		perms[role].include?(action)
	end

	module_function :authorise?

end


