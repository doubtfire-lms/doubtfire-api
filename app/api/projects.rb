require 'grape'

module Api
  class Projects < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get projects"
    params do
      optional :unit_role_id, type: Integer, desc: "Get current user's project related to the indicated unit role"
    end
    get '/projects' do
      
      if params[:unit_role_id]
        unit_role = UnitRole.find(params[:unit_role_id])
        projects = Project.for_unit_role(unit_role)
        # projects.where(unit_role_id: params[:unit_role_id])
      else
        projects = Project.for_user current_user
      end
    end

    desc "Get project"
    get '/projects/:id' do
      project = Project.find(params[:id])

      if authorise? current_user, project, :get
        project
      else
        error!({"error" => "Couldn't find Project with id=#{params[:id]}" }, 403)
      end
    end
  end
end
