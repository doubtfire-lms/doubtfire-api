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
      requires :trigger, type: String, desc: 'The update trigger'
    end
    put '/projects/:id' do
      project = Project.find(params[:id])

      if params[:trigger] == "trigger_week_end"
        if authorise? current_user, project, :trigger_week_end
          project.trigger_week_end( current_user )
        else
          error!({"error" => "Couldn't find Project with id=#{params[:id]}" }, 403)
        end
        project
      else
        error!({"error" => "Invalid trigger - #{params[:trigger]} unknown" }, 403)
      end 
    end

    desc "Create a project"
    params do
        requires :unit_id         , type: Integer,   desc: 'Unit Id'
        requires :student_num      , type: String,   desc: 'Student Number 7 digit code'
        optional :tutorial_id     , type: Integer,  desc: 'Tutorial Id'
    end
    post '/projects' do
      unit = Unit.find(params[:unit_id])
      student = User.find_by_username(params[:student_num])

      if student.nil?
        error!({"error" => "Couldn't find Student with username=#{params[:student_num]}" }, 403)
      end

      if authorise? current_user, unit, :enrol_student
        proj = unit.add_user(student.id, params[:tutorial_id])
        if proj.nil? 
          error!({"error" => "Error adding student to unit" }, 403)
        else 
          StudentProjectSerializer.new proj
        end
      else
        error!({"error" => "Couldn't find Unit with id=#{params[:unit_id]}" }, 403)
      end


    end
  end
end
