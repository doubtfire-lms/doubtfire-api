require 'grape'
require 'project_serializer'

module Api
  class Projects < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Fetches all of the current user's projects - or those for a given role for tutors"
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
    params do
      requires :id, type: Integer, desc: "The id of the project to get"
    end
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
      optional :trigger,            type: String,  desc: 'The update trigger'
      optional :tutorial_id,        type: Integer, desc: 'Switch tutorial'
      optional :enrolled,           type: Boolean, desc: 'Enrol or withdraw this project'
      optional :target_grade,       type: Integer, desc: 'New target grade'
      optional :compile_portfolio,  type: Boolean, desc: 'Schedule a construction of the portfolio'
    end
    put '/projects/:id' do
      project = Project.find(params[:id])

      if params[:trigger].nil? == false
        if params[:trigger] == "trigger_week_end"
          if authorise? current_user, project, :trigger_week_end
            project.trigger_week_end( current_user )
          else
            error!({"error" => "You are not authorised to perform this action for Project with id=#{params[:id]}" }, 403)
          end
        else
          error!({"error" => "Invalid trigger - #{params[:trigger]} unknown" }, 403)
        end
      elsif not params[:tutorial_id].nil?
        if not authorise? current_user, project, :change_tutorial
          error!({"error" => "Couldn't find Project with id=#{params[:id]}" }, 403)
        end

        tutorial_id = params[:tutorial_id]
        if project.unit.tutorials.where('tutorials.id = :tutorial_id', tutorial_id: tutorial_id).count == 1
          project.tutorial_id = tutorial_id
          project.save!
        elsif tutorial_id == -1
          project.tutorial = nil
          project.save!
        else
          error!({"error" => "Couldn't find Tutorial with id=#{params[:tutorial_id]}" }, 403)
        end
      elsif not params[:enrolled].nil?
        if not authorise? current_user, project.unit, :change_project_enrolment
          error!({"error" => "You cannot change the enrolment for project #{params[:id]}" }, 403)
        end
        project.enrolled = params[:enrolled]
        project.save
      elsif not params[:target_grade].nil?
        project.target_grade = params[:target_grade]
        project.save
      elsif not params[:compile_portfolio].nil?
        project.compile_portfolio = params[:compile_portfolio]
        project.save
      end

      project
    end #put

    desc "Enrol a student in a unit, creating them a project"
    params do
        requires :unit_id         , type: Integer,   desc: 'Unit Id'
        requires :student_num     , type: String,   desc: 'Student Number 7 digit code'
        optional :tutorial_id     , type: Integer,  desc: 'Tutorial Id'
    end
    post '/projects' do
      unit = Unit.find(params[:unit_id])
      student = User.find_by_username(params[:student_num])

      if student.nil?
        error!({"error" => "Couldn't find Student with username=#{params[:student_num]}" }, 403)
      end
      
      if authorise? current_user, unit, :enrol_student
        proj = unit.enrol_student(student, params[:tutorial_id])
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
