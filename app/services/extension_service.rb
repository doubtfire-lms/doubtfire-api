class ExtensionService
  def self.grant_extension(project_id, task_definition_id, user, weeks_requested, comment, is_staff_grant: false)
    # Find project and task
    project = Project.find(project_id)
    task_definition = project.unit.task_definitions.find(task_definition_id)
    task = project.task_for_task_definition(task_definition)

    # ===== Common Validation Logic (used by both endpoints) =====
    # Validate extension weeks
    return { success: false, error: 'Extension weeks cannot be 0', status: 403 } if weeks_requested == 0

    # Calculate max duration
    max_duration = task.weeks_can_extend
    duration = weeks_requested
    duration = max_duration unless weeks_requested <= max_duration

    # Check if extension would exceed deadline
    return { success: false, error: 'Extensions cannot be granted beyond task deadline', status: 403 } if duration <= 0

    # === Flexible dates rule ===
    if !is_staff_grant && project.unit.allow_flexible_dates
      return {
        success: false,
        error: 'Extensions are disabled for this unit.',
        status: 403
      }
    end

    # ===== Student-Initiated Extension Logic (current endpoint) =====
    unless is_staff_grant ||
           AuthorisationHelpers.authorise?(
             user,
             task,
             :request_extension,
             ->(role, perm_hash, other) { task.specific_permission_hash(role, perm_hash, other) }
           )
      return {
        success: false,
        error: 'Not authorised to request an extension for this task',
        status: 403
      }
    end

    # ===== Staff Grant Logic (new endpoint) =====
    if is_staff_grant &&
       !AuthorisationHelpers.authorise?(user, project.unit, :grant_extensions)
      return {
        success: false,
        error: 'Not authorised to grant extensions for this unit',
        status: 403
      }
    end

    # ===== Common Extension Logic =====
    # Apply the extension
    result = task.apply_for_extension(user, comment, duration)

    # Auto-approve if it's a staff grant
    if is_staff_grant
      extension_comment = result.becomes(ExtensionComment)
      extension_comment.assess_extension(user, true, true)
    end

    { success: true, result: result, status: 201 }
  rescue ActiveRecord::RecordNotFound => e
    { success: false, error: 'Task or project not found', status: 404 }
  rescue StandardError => e
    { success: false, error: e.message, status: 500 }
  end
end
