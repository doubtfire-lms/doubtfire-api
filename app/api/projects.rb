require 'grape'
require 'project_serializer'

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

        #
        # Only allow this if the current user + unit_role has permission to get projects
        #
        if authorise? current_user, unit_role, :getProjects
          projects = Project.for_unit_role(unit_role)
        else
          error!({"error" => "Couldn't find Projects with unit_role_id=#{params[:unit_role_id]}" }, 403)
        end
      else
        projects = Project.for_user current_user
      end

      ActiveModel::ArraySerializer.new(projects, each_serializer: ShallowProjectSerializer)
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

    desc "Update a project"
    params do
      requires :id, type: Integer, desc: 'The project id of the project to'
      requires :trigger, type: String, desc: 'The update trigger'
    end
    put '/projects/:id' do
      project = Project.find(params[:id])

      if params[:trigger] = "trigger_week_end" and authorise? current_user, project, :trigger_week_end
        project.trigger_week_end( current_user )
        project
      else
        error!({"error" => "Couldn't find Project with id=#{params[:id]}" }, 403)
      end 
    end

  end
end
