require 'grape'
require 'unit_serializer'
require 'mime-check-helpers'

module Api
  class Units < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers
    helpers MimeCheckHelpers

    before do
      authenticated?

      if params[:unit]
        for key in [ :start_date, :end_date ] do
          if params[:unit][key].present?
            date_val  = DateTime.parse(params[:unit][key])
            params[:unit][key]  = date_val
          end
        end
      end
    end

    desc "Get units related to the current user for admin purposes"
    params do
      optional :include_in_active, type: Boolean, desc: 'Include units that are not active'
    end
    get '/units' do
      if not authorise? current_user, User, :convene_units
        error!({"error" => "Unable to list units" }, 403)
      end

      # gets only the units the current user can "see"
      units = Unit.for_user_admin current_user

      if not params[:include_in_active]
        units = units.where("active = true")
      end

      ActiveModel::ArraySerializer.new(units, each_serializer: ShallowUnitSerializer)
    end

    desc "Get a unit's details"
    get '/units/:id' do
      unit = Unit.find(params[:id])
      if not ((authorise? current_user, unit, :get_unit) || (authorise? current_user, User, :admin_units))
        error!({"error" => "Couldn't find Unit with id=#{params[:id]}" }, 403)
      end
      #
      # Unit uses user from thread to limit exposure
      #
      Thread.current[:user] = current_user
      unit
    end


    desc "Update unit"
    params do
      requires :id, type: Integer, desc: 'The unit id to update'
      requires :unit, type: Hash do
        optional :name
        optional :code
        optional :description
        optional :start_date
        optional :end_date
        optional :active
      end
    end
    put '/units/:id' do
      unit= Unit.find(params[:id])
      if not authorise? current_user, unit, :update
        error!({"error" => "Not authorised to update a unit" }, 403)
      end
      unit_parameters = ActionController::Parameters.new(params)
      .require(:unit)
      .permit(:name,
              :code,
              :description,
              :start_date,
              :end_date,
              :active
             )

      unit.update!(unit_parameters)
      unit_parameters
    end


    desc "Create unit"
    params do
      requires :unit, type: Hash do
        requires :name
        requires :code
        optional :description
        optional :start_date
        optional :end_date
      end
    end
    post '/units' do
      if not authorise? current_user, User, :create_unit
        error!({"error" => "Not authorised to create a unit" }, 403)
      end

      unit_parameters = ActionController::Parameters.new(params)
                                          .require(:unit)
                                          .permit(
                                            :name,
                                            :code,
                                            :description,
                                            :start_date,
                                            :end_date
                                          )

      if unit_parameters[:description].nil?
        unit_parameters[:description] = unit_parameters[:name]
      end
      if unit_parameters[:start_date].nil?
        start_date = Date.parse('Monday')
        delta = start_date > Date.today ? 0 : 7
        unit_parameters[:start_date] = start_date + delta
      end
      if unit_parameters[:end_date].nil?
        unit_parameters[:end_date] = unit_parameters[:start_date] + 16.weeks
      end

      unit = Unit.create!(unit_parameters)

      # Employ current user as convenor
      unit.employ_staff(current_user, Role.convenor)
      ShallowUnitSerializer.new(unit)
    end

    desc "Add a tutorial with the provided details to this unit"
    params do
      #day, time, location, tutor_username, abbrev
      requires :tutorial, type: Hash do
        requires :day
        requires :time
        requires :location
        requires :tutor_username
        requires :abbrev
      end
    end
    post '/units/:id/tutorials' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :add_tutorial
        error!({"error" => "Not authorised to create a tutorial" }, 403)
      end

      new_tutorial = params[:tutorial]
      tutor = User.find_by_username(new_tutorial[:tutor_username])
      if tutor.nil?
        error!({"error" => "Couldn't find User with username=#{new_tutorial[:tutor_username]}" }, 403)
      end

      result = unit.add_tutorial(new_tutorial[:day], new_tutorial[:time], new_tutorial[:location], tutor, new_tutorial[:abbrev])
      if result.nil?
        error!({"error" => "Tutor username invalid (not a tutor for this unit)" }, 403)
      end

      result
    end

    desc "Download the tasks that are awaiting feedback for a unit"
    get '/units/:id/feedback' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :provide_feedback
        error!({"error" => "Not authorised to provide feedback for this unit" }, 403)
      end

      ActiveModel::ArraySerializer.new(unit.tasks_awaiting_feedback, each_serializer: TaskFeedbackSerializer)
    end

    desc "Download the grades for a unit"
    get '/units/:id/grades' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_grades
        error!({"error" => "Not authorised to download grades for this unit" }, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv "
      env['api.format'] = :binary

      unit.student_grades_csv
    end

    desc "Upload CSV of all the students in a unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
    end
    post '/csv/units/:id' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :upload_csv
        error!({"error" => "Not authorised to upload CSV of students to #{unit.code}"}, 403)
      end

      ensure_csv!(params[:file][:tempfile])

      # Actually import...
      unit.import_users_from_csv(params[:file][:tempfile])
    end

    desc "Upload CSV with the students to un-enrol from the unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
    end
    post '/csv/units/:id/withdraw' do
      # check mime is correct before uploading
      ensure_csv!(params[:file][:tempfile])

      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :upload_csv
        error!({"error" => "Not authorised to upload CSV of students to #{unit.code}"}, 403)
      end

      # Actually withdraw...
      unit.unenrol_users_from_csv(params[:file][:tempfile])
    end

    desc "Download CSV of all students in this unit"
    get '/csv/units/:id' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_unit_csv
        error!({"error" => "Not authorised to download CSV of students enrolled in #{unit.code}"}, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv "
      env['api.format'] = :binary
      unit.export_users_to_csv
    end

    desc "Download CSV of all student tasks in this unit"
    get '/csv/units/:id/task_completion' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_unit_csv
        error!({"error" => "Not authorised to download CSV of student tasks in #{unit.code}"}, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-TaskCompletion.csv "
      env['api.format'] = :binary
      unit.task_completion_csv
    end

    desc "Download the stats related to the number of students aiming for each grade"
    get '/units/:id/stats/student_target_grade' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_stats
        error!({"error" => "Not authorised to download stats of student tasks in #{unit.code}"}, 403)
      end

      unit.student_target_grade_stats
    end

    desc "Download stats related to the status of students with tasks"
    get '/units/:id/stats/task_status_pct' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_stats
        error!({"error" => "Not authorised to download stats of student tasks in #{unit.code}"}, 403)
      end

      unit.task_status_stats
    end

    desc "Download stats related to the number of completed tasks"
    get '/units/:id/stats/task_completion_stats' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :download_stats
        error!({"error" => "Not authorised to download stats of student tasks in #{unit.code}"}, 403)
      end

      unit.student_task_completion_stats
    end
  end


end
