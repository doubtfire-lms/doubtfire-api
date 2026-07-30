module AuthorisationHelpers
  def get_permission_hash(role, perm_hash, _other)
    perm_hash[role] unless perm_hash.nil?
  end

  OBSERVER_ONLY_PERMISSIONS = [
    :get,
    :get_unit_roles,
    :download_unit_csv,
    :get_teaching_periods,
    :get_scorm_token,
    :get_feedback_chips,
    :get_all_units,
    :list_users,
    :get_staff_list,
    :get_user,
    :download_system_csv,
    :get_unit,
    :get_students,
    :download_stats,
    :download_grades,
    :download_jplag_report,
    :get_submission,
    :view_plagiarism,
    :get_discussion,
    :get_staff_note,
    :get_members,
    :get_groups,
    :get_discussion_prompt,
    :get_engagements,
    :get_tutor_times
  ].freeze

  #
  # Authorises if the user can perform an action on the object
  #
  # user - who
  # object - context, what are we asking for permissions from
  # action - what action
  # perm_get_fn - which method do we call to get the permission hash. Can be used to get different hashes in different contexts. This returns hash of actions permitted
  #
  def authorise?(user, object, action, perm_get_fn = method(:get_permission_hash), other = nil)
    # Can pass in instance or class
    obj_class = object.class == Class ? object : object.class

    # System administrators retain their administrator permissions even when
    # they have a lower-level role within the object's unit.
    system_admin = user.has_admin_capability?
    role_obj = system_admin ? user.role : object.role_for(user)

    return false if role_obj.nil?

    unless system_admin
      # Attempt to get the unit role from a Unit context
      unit_role = object&.unit_role_for(user) if object.respond_to?(:unit_role_for)

      # Attempt to get the unit role if object has a unit reference
      if unit_role.nil? && object.respond_to?(:unit)
        unit_role = object.unit.unit_role_for(user)
      end

      if !unit_role.nil? && unit_role.observer_only && !OBSERVER_ONLY_PERMISSIONS.include?(action)
        return false
      end
    end

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
