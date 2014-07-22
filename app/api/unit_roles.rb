require 'grape'

module Api
  class UnitRoles < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get unit roles for authenticated user"
    params do
      optional :unit_id, type: Integer, desc: 'Get user roles in indicated unit'
    end
    get '/unit_roles' do
      unit_roles = UnitRole.for_user current_user

      if params[:unit_id]
        unit_roles = unit_roles.where(unit_id: params[:unit_id])
      end

      unit_roles
    end

    desc "Delete a unit role"
    delete '/unit_roles/:id' do 
      unit_role = UnitRole.find(params[:id])
      #if authorise? current_user, unit_role, :delete
      unit_role.destroy
      #end 
    end


    desc "Get a unit_role's details"
    get '/unit_roles/:id' do
      unit_role = UnitRole.find(params[:id])

      if authorise? current_user, unit_role, :get
        unit_role
      else
        error!({"error" => "Couldn't find UnitRole with id=#{params[:id]}" }, 403)
      end
    end


    desc "Create a role " 
    params do 
      requires :unit_id, type: Integer, desc: 'Unit id'
      requires :user_id, type: Integer, desc: 'User id'
      requires :role, type: String, desc: 'The role to create with'
    end 
    post '/unit_roles' do 
      role = UnitRole.new
      role.user_id = params[:user_id]
      role.unit_id = params[:unit_id]
      role.role_id = Role.where("name = :role",role: params[:role]).first.id
      role.save
      role
    end 

    desc "Update a role " 
    params do 
      group :unit_role do 
        requires :unit_id, type: Integer, desc: 'Unit id'
        requires :user_id, type: Integer, desc: 'User id'
        requires :role_id, type: Integer, desc: 'The role to create with'
      end 
    end 
    put '/unit_roles/:id' do 
      unit_role_parameters = ActionController::Parameters.new(params)
        .require(:unit_role)
        .permit(
          :unit_id,
          :user_id,
          :role_id, 
          :tutorial_id
        )
      role = UnitRole.find_by_id(params[:id])
      role.update!(unit_role_parameters)
      role
    end 


  end
end
