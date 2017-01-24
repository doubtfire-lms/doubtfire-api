module AuthorisationHelpers
  def get_permission_hash(role, perm_hash, _other)
    perm_hash[role] unless perm_hash.nil?
  end

  #
  # Authorises if the user can perform an action on the object
  #
  def authorise?(user, object, action, perm_get_fn = method(:get_permission_hash), other = nil)
    # Can pass in instance or class
    obj_class = object.class == Class ? object : object.class

    role_obj = object.role_for(user)

    return false if role_obj.nil?

    role = role_obj.to_sym
    perm_hash = obj_class.permissions
    perms = perm_get_fn.call(role, perm_hash, other)

    # No permissions, default to false authorise, else check if the action
    # is in the permissions hash
    perms.nil? ? false : perms.include?(action)
  end

  module_function :get_permission_hash
  module_function :authorise?
end
