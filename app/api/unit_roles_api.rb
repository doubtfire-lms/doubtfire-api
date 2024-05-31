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
    end
  end
  put '/unit_roles/:id' do
    unit_role = UnitRole.find_by(id: params[:id])

    unless (authorise? current_user, unit_role.unit, :employ_staff) || (authorise? current_user, User, :admin_units)
      error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
    end

    unit_role_parameters = ActionController::Parameters.new(params)
                                                       .require(:unit_role)
                                                       .permit(
                                                         :role_id
                                                       )

    if unit_role_parameters[:role_id] == Role.tutor.id && unit_role.role == Role.convenor && unit_role.unit.convenors.count == 1
      error!({ error: 'There must be at least one convenor for the unit' }, 403)
    end

    unit_role.update!(unit_role_parameters)
    present unit_role, with: Entities::UnitRoleEntity, in_unit: true
  end
end
