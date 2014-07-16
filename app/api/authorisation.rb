module AuthorisationHelpers

	def authorise? (user, object, action, context = nil)
		# can pass in object or class
		if object.class == Class
		  obj_class = object
		else
  		obj_class = object.class
  		

		perms = obj_class.permissions

		role = object.role_for(user)

    if context.nil?
  		perms[role].include?(action)
    else
      perms[role][action].include?(context)
    end
	end

	module_function :authorise?

end


