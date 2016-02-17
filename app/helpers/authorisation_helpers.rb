module AuthorisationHelpers

  def get_permission_hash(role, perm_hash, other)
    perm_hash[role] unless perm_hash.nil?
  end

  def authorise? (user, object, action, perm_get_fn = method(:get_permission_hash), other = nil)
    # can pass in object or class
    if object.class == Class
      obj_class = object
    else
      obj_class = object.class
    end

    role_obj = object.role_for(user) and role = role_obj.to_sym()
    perm_hash = obj_class.permissions
    perms = perm_get_fn.call(role, perm_hash, other)

    if perms.nil?
      false
    else 
      perms.include?(action)
    end
  end

  module_function :get_permission_hash
  module_function :authorise?

end