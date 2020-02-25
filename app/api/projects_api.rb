require 'grape'
require 'project_serializer'

module Api
  class ProjectsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers DbHelpers

    before do
      authenticated?
    end

    desc "Fetches all of the current user's projects"
    params do
      optional :include_inactive, type: Boolean, desc: 'Include projects for units that are no longer active?'
    end
    get '/projects' do
      include_inactive = params[:include_inactive] || false

      projects = Project.for_user current_user, include_inactive

      student_name = db_concat('users.first_name', "' '", 'users.last_name')

      # join in other tables to fetch data
      data = projects.
                 joins(:unit).
                 joins(:user).
                 select( 'projects.*',
                          'units.name AS unit_name', 'units.id AS unit_id', 'units.code AS unit_code', 'units.start_date AS start_date', 'units.end_date AS end_date', 'units.teaching_period_id AS teaching_period_id', 'units.active AS active',
                          "#{student_name} AS student_name"
                        )

      # Now map the data to structure for json to return
      data.map do |row|
        {
          unit_id: row['unit_id'],
          unit_code: row['unit_code'],
          unit_name: row['unit_name'],
          project_id: row['id'],
          campus_id: row['campus_id'],
          target_grade: row['target_grade'],
          has_portfolio: row['has_portfolio'],
          start_date: row['start_date'],
          end_date: row['end_date'],
          teaching_period_id: row['teaching_period_id'],
          active: row['active'].is_a?(Numeric) ? row['active'] != 0 : row['active']
        }
      end
    end

    desc 'Get project'
    params do
      requires :id, type: Integer, desc: 'The id of the project to get'
    end
    get '/projects/:id' do
      project = Project.find(params[:id])

      if authorise? current_user, project, :get
        project
      else
        error!({ error: "Couldn't find Project with id=#{params[:id]}" }, 403)
      end

      Thread.current[:user] = current_user
      project
    end

    desc 'Update a project'
    params do
      optional :trigger,            type: String,  desc: 'The update trigger'
      optional :campus_id,          type: Integer, desc: 'Campus this project is part of, or -1 for no campus'
      optional :enrolled,           type: Boolean, desc: 'Enrol or withdraw this project'
      optional :target_grade,       type: Integer, desc: 'New target grade'
      optional :compile_portfolio,  type: Boolean, desc: 'Schedule a construction of the portfolio'
      optional :grade,              type: Integer, desc: 'New grade'
      optional :old_grade,          type: Integer, desc: 'Old grade to check it has not changed...'
      optional :grade_rationale,    type: String,  desc: 'New grade rationale'
    end
    put '/projects/:id' do
      project = Project.find(params[:id])

      if params[:trigger].nil? == false
        if params[:trigger] == 'trigger_week_end'
          if authorise? current_user, project, :trigger_week_end
            project.trigger_week_end(current_user)
          else
            error!({ error: "You are not authorised to perform this action for Project with id=#{params[:id]}" }, 403)
          end
        else
          error!({ error: "Invalid trigger - #{params[:trigger]} unknown" }, 403)
        end
      # If we are only updating the campus
      elsif params[:campus_id].present?
        unless authorise? current_user, project, :change_campus
          error!({ error: "You cannot change the campus for project #{params[:id]}" }, 403)
        end
        project.campus_id = params[:campus_id] == -1 ? nil : params[:campus_id]
        project.save!
      elsif !params[:enrolled].nil?
        unless authorise? current_user, project.unit, :change_project_enrolment
          error!({ error: "You cannot change the enrolment for project #{params[:id]}" }, 403)
        end
        project.enrolled = params[:enrolled]
        project.save
      elsif !params[:target_grade].nil?
        unless authorise? current_user, project, :change
          error!({ error: "You do not have permissions to change Project with id=#{params[:id]}" }, 403)
        end

        project.target_grade = params[:target_grade]
        project.save
      elsif !params[:grade].nil?
        unless authorise? current_user, project, :assess
          error!({ error: "You do not have permissions to assess Project with id=#{params[:id]}" }, 403)
        end

        if params[:grade_rationale].nil?
          error!({ error: 'Grade rationale required to perform assessment.' }, 403)
        end

        if params[:old_grade].nil?
          error!({ error: 'Existing project grade is required to perform assessment.' }, 403)
        end

        if params[:old_grade] != project.grade
          error!({ error: 'Existing project grade does not match current grade. Refresh project and try again.' }, 403)
        end

        project.grade = params[:grade]
        project.grade_rationale = params[:grade_rationale]
        project.save!
      elsif !params[:compile_portfolio].nil?
        unless authorise? current_user, project, :change
          error!({ error: "You do not have permissions to change Project with id=#{params[:id]}" }, 403)
        end

        project.compile_portfolio = params[:compile_portfolio]
        project.save
      end

      Thread.current[:user] = current_user
      project
    end # put

    desc 'Enrol a student in a unit, creating them a project'
    params do
      requires :unit_id, type: Integer, desc: 'Unit Id'
      requires :student_num, type: String,   desc: 'Student Number 7 digit code'
      requires :campus_id, type: Integer, desc: 'Campus this project is part of'
    end
    post '/projects' do
      unit = Unit.find(params[:unit_id])
      student = User.find_by(username: params[:student_num])
      student = User.find_by(student_id: params[:student_num]) if student.nil?
      student = User.find_by(email: params[:student_num]) if student.nil?

      if student.nil?
        error!({ error: "Couldn't find Student with username=#{params[:student_num]}" }, 403)
      end

      campus = Campus.find(params[:campus_id])

      if authorise? current_user, unit, :enrol_student
        proj = unit.enrol_student(student, campus)
        if proj.nil?
          error!({ error: 'Error adding student to unit' }, 403)
        else
          {
            project_id: proj.id,
            enrolled: proj.enrolled,
            first_name: proj.student.first_name,
            last_name: proj.student.last_name,
            student_id: proj.student.username,
            student_email: proj.student.email,
            target_grade: proj.target_grade,
            campus_id: proj.campus_id,
            compile_portfolio: false,
            grade: proj.grade,
            grade_rationale: proj.grade_rationale,
            max_pct_copy: 0,
            has_portfolio: false,
            stats: '0|1|0|0|0|0|0|0|0|0|0'
          }
        end
      else
        error!({ error: "Couldn't find Unit with id=#{params[:unit_id]}" }, 403)
      end
    end
  end
end
