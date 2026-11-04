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
    :get_staff_notes,
    :get_members,
    :get_groups,
    :get_discussion_prompt,
    :get_engagements,
    :get_tutor_times,
    :get_tutor_times_summary,
    :get_marking_sessions,
    :get_los,
    :view_staff_inbox,
    :download_overflow_stats
  ].freeze

  # Observers may use these permissions only on GET requests because the same
  # actions also authorise write requests.
  # TODO: Split read and write permissions so this check does not depend on the HTTP method.
  OBSERVER_ONLY_GET_PERMISSIONS = [
    :update,
    :provide_feedback,
    :create_feedback_chips,
    :manage_unit_content,
    :mannage_communications,
    :add_task_def,
    :create_tutor_note
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
    perm_hash = obj_class.permissions

    return true if obj_class == User && action == :get_all_units && user.observe_all_units?
    return true if obj_class == User && action == :get_staff_list && user.observe_all_units?

    # System administrator permissions take precedence over contextual roles.
    if user.has_admin_capability?
      system_perms = perm_get_fn.call(user.role.to_sym, perm_hash, other)
      return true if system_perms&.include?(action)
    end

    role_obj = object.role_for(user)

    # Attempt to get the unit role from a Unit context
    unit_role = object&.unit_role_for(user) if object.respond_to?(:unit_role_for)

    # Attempt to get the unit role if object has a unit reference
    if unit_role.nil? && object.respond_to?(:unit)
      unit_role = object.unit.unit_role_for(user)
    end

    global_observer = user.observe_all_units? && unit_role.nil? &&
                      (object.is_a?(Unit) || object.respond_to?(:unit))
    if global_observer
      role_obj = object.is_a?(Project) || object.is_a?(Task) ? Role.tutor : Role.convenor
    end

    observer_read_permission = OBSERVER_ONLY_PERMISSIONS.include?(action) ||
                               (OBSERVER_ONLY_GET_PERMISSIONS.include?(action) && respond_to?(:request) && request.get?)
    if (global_observer || unit_role&.observer_only?) && !observer_read_permission
      return false
    end

    return false if role_obj.nil?

    role = role_obj.to_sym
    perms = perm_get_fn.call(role, perm_hash, other)

    # No permissions, default to false authorise, else check if the action
    # is in the permissions hash
    perms.nil? ? false : perms.include?(action)
  end

  module_function :get_permission_hash
  module_function :authorise?
end
