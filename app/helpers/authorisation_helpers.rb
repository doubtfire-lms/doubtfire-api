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

  PORTFOLIO_LOCKED_PROJECT_ACTIONS = [
    :make_submission,
    :change,
    :trigger_week_end,
    :reprocess_submission
  ].freeze

  PORTFOLIO_LOCKED_TASK_READ_ACTIONS = [
    :get,
    :get_submission,
    :get_discussion,
    :view_plagiarism,
    :review_own_attempt,
    :review_other_attempt
  ].freeze

  def portfolio_lock_project_for(object)
    return object if object.is_a?(Project)
    return object.project if object.respond_to?(:project)
    return object.task.project if object.respond_to?(:task) && object.task.respond_to?(:project)

    nil
  end

  def portfolio_lock_blocks?(object, action)
    project = portfolio_lock_project_for(object)
    return false unless project&.portfolio_locked?

    if object.is_a?(Project)
      PORTFOLIO_LOCKED_PROJECT_ACTIONS.include?(action)
    else
      !PORTFOLIO_LOCKED_TASK_READ_ACTIONS.include?(action)
    end
  end

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

    return false if object.class != Class && portfolio_lock_blocks?(object, action)

    # System administrator permissions take precedence over contextual roles.
    if user.has_admin_capability?
      system_perms = perm_get_fn.call(user.role.to_sym, perm_hash, other)
      return true if system_perms&.include?(action)
    end

    role_obj = object.role_for(user)

    return false if role_obj.nil?

    # Attempt to get the unit role from a Unit context
    unit_role = object&.unit_role_for(user) if object.respond_to?(:unit_role_for)

    # Attempt to get the unit role if object has a unit reference
    if unit_role.nil? && object.respond_to?(:unit)
      unit_role = object.unit.unit_role_for(user)
    end

    if !unit_role.nil? && unit_role.observer_only && !OBSERVER_ONLY_PERMISSIONS.include?(action)
      return false
    end

    role = role_obj.to_sym
    perms = perm_get_fn.call(role, perm_hash, other)

    # No permissions, default to false authorise, else check if the action
    # is in the permissions hash
    perms.nil? ? false : perms.include?(action)
  end

  module_function :get_permission_hash
  module_function :portfolio_lock_project_for
  module_function :portfolio_lock_blocks?
  module_function :authorise?
end
