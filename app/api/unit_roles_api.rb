require 'grape'

class UnitRolesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Get unit roles for authenticated user'
  params do
    optional :active_only, type: Boolean, desc: 'Show only active roles'
  end
  get '/unit_roles' do
    return [] unless authorise? current_user, User, :get_unit_roles

    result = UnitRole.includes(:unit).where(unit_roles: { user_id: current_user.id })

    if params[:active_only]
      result = result.where(unit_roles: { active: true })
    end

    present result, with: Entities::UnitRoleEntity, user: current_user
  end

  desc 'Delete a unit role'
  delete '/unit_roles/:id' do
    unit_role = UnitRole.find(params[:id])

    unless (authorise? current_user, unit_role.unit, :employ_staff) || (authorise? current_user, User, :admin_units)
      error!({ error: "You do not have permission to perform this action" }, 403)
    end

    unit_role.destroy!
  end

  desc 'Employ a user as a teaching role in a unit'
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit to employ the staff for'
    requires :user_id, type: Integer, desc: 'The id of the tutor'
    requires :role, type: String, desc: 'The role for the staff member'
  end
  post '/unit_roles' do
    unit = Unit.find(params[:unit_id])

    unless (authorise? current_user, unit, :employ_staff) || (authorise? current_user, User, :admin_units)
      error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
    end
    user = User.find(params[:user_id])
    role = Role.with_name(params[:role])

    if role.nil?
      error!({ error: "Couldn't find Role with name=#{params[:role]}" }, 403)
    end

    if role == Role.student
      error!({ error: 'Enrol students as projects not unit roles' }, 403)
    end

    unless user.has_tutor_capability?
      error!({ error: 'The selected user is not a tutor. Please update their system role before adding them' }, 403)
    end

    result = unit.employ_staff(user, role)
    present result, with: Entities::UnitRoleEntity, in_unit: true
  end

  desc 'Update a role'
  params do
    requires :unit_role, type: Hash do
      requires :role_id, type: Integer, desc: 'The role to create with'
      optional :observer_only, type: Boolean, desc: 'If the staff has read-only permissions'
      optional :mentor_id, type: Integer, desc: 'Assign a mentor to this unit role'
    end
  end
  put '/unit_roles/:id' do
    unit_role = UnitRole.find_by(id: params[:id])

    unless (authorise? current_user, unit_role.unit, :employ_staff) || (authorise? current_user, User, :admin_units)
      error!({ error: "Not authorised to update unit role with id=#{params[:id]}" }, 403)
    end

    # Prevent staff from setting themselves as read-only
    if params[:unit_role][:observer_only] && unit_role.user.id == current_user.id
      error!({ error: "You cannot make yourself an observer" }, 403)
    end

    # Once they're an observer, they'll no longer have access to this route to remove the observer status from themselves
    # But let's double check just in case this route gets whitelisted...

    unit = unit_role.unit
    current_unit_role = unit.unit_role_for(current_user)

    if current_unit_role.observer_only
      error!({ error: "You are not authorised to update this staff member." }, 403)
    end

    unit_role_parameters = ActionController::Parameters.new(params)
                                                       .require(:unit_role)
                                                       .permit(
                                                         :role_id,
                                                         :observer_only,
                                                         :mentor_id
                                                       )

    if unit_role_parameters[:role_id] == Role.tutor.id && unit_role.role == Role.convenor && unit_role.unit.convenors.count == 1
      error!({ error: 'There must be at least one convenor for the unit' }, 403)
    end

    unit_role.update!(unit_role_parameters)
    present unit_role, with: Entities::UnitRoleEntity, in_unit: true
  end

  desc 'Moderate tutor feedback'
  params do
    requires :id, type: Integer, desc: 'The id of the unit role to moderate'
    requires :task_id, type: Integer, desc: 'The id of the task'
    requires :action, type: String, desc: 'Action to apply to this moderated task'
    optional :apply_to_all, type: Boolean, desc: 'Should this action be applied to all moderated tasks for this tutor in this task definition'
  end
  post '/unit_roles/:id/moderation/:task_id' do
    unit_role = UnitRole.find(params[:id])
    unit = unit_role.unit

    task = Task.find(params[:task_id])
    tutor_user = task.project.tutor_for(task.task_definition)
    tutor = unit.unit_role_for(tutor_user)
    unless tutor.id == unit_role.id
      error!("Invalid unit role", 400)
    end

    current_unit_role = unit.unit_role_for(current_user)
    unless tutor.mentor == current_unit_role
      error!({ error: 'You do not have permission to moderate this feedback' }, 400)
    end

    action = params[:action].downcase
    unless %w[show_more show_less dismiss_ok upheld overturn].include?(action)
      error!({ error: 'Invalid moderation action' }, 400)
    end

    moderated_task = ModeratedTask.find_by(task: task)

    if moderated_task.escalation?
      unless %w[upheld overturn].include?(action)
        error!({ error: 'This task is under Feedback Review. Only review actions (upheld or overturn) are allowed. Please refresh the moderation queue.' }, 400)
      end
    else
      unless %w[show_more show_less dismiss_ok].include?(action)
        error!({ error: 'Invalid action for this moderated task. Please refresh moderation queue.' }, 400)
      end
    end

    recent_threshold = 15.minutes.ago
    if moderated_task.last_moderated_date && moderated_task.last_moderated_date > recent_threshold
      error!({ error: 'Feedback is too new to moderate' }, 400)
    end

    apply_to_all = params[:apply_to_all]

    if apply_to_all && !%w[show_less dismiss_ok].include?(action)
      error!({ error: 'Bulk moderation can only be used when dismissing a task or seeing less from a tutor' }, 400)
    end

    if moderated_task.resolved?
      error!({ error: 'This moderated task has already been resolved. Please refresh moderation queue.' }, 400)
    end

    state = nil
    outcome = nil

    case action
    when 'show_more'
      delta = -1
      state = :waiting_for_new_feedback
    when 'show_less'
      delta = 1
      state = :resolved
      outcome = :dismissed_good
    when 'dismiss_ok'
      delta = 0
      state = :resolved
      outcome = :dismissed_ok
    when 'overturn'
      delta = -1
      state = :resolved
      outcome = :overturned
    when 'upheld'
      delta = 0
      state = :resolved
      outcome = :upheld
    end

    factor = Doubtfire::Application.config.moderation_score_factor

    td_score = TutorFeedbackScore.find_by(unit_role: unit_role, task_definition: task.task_definition)
    if td_score.nil?
      td_score = TutorFeedbackScore.create!({
                                              unit_role: unit_role,
                                              task_definition: task.task_definition,
                                              score: 50
                                            })
    end

    attrs = {
      last_moderated_date: Time.zone.now,
      resolved_by_user_id: current_user.id,
      state: state,
      outcome: outcome
    }

    ActiveRecord::Base.transaction do
      count = 1

      if apply_to_all
        count = 0
        task_ids = unit.tasks.where(task_definition: task.task_definition)
          .select { |t| t.tutor == tutor.user }
          .map(&:id)

        moderated_tasks =
          ModeratedTask.where(task_id: task_ids)
                       .where(state: %i[open waiting_for_new_feedback]) # Only update active moderation tasks
                       .where(moderation_type: %i[first_feedback random_sample]) # Don't updated escalated tasks

        moderated_tasks.find_each do |mt|
          next if mt.resolved?
          count += 1
          mt.update!(attrs)
        end
      else
        moderated_task.update!(attrs)
      end

      td_score.update!(
        score: (td_score.score + (delta * factor * count)).clamp(0, 99)
      )
    end

    true
  end
end
