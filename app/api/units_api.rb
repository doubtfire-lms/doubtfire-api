require 'grape'
require 'unit_serializer'
require 'mime-check-helpers'
require 'csv_helper'

module Api
  class UnitsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers MimeCheckHelpers
    helpers CsvHelper


    before do
      authenticated?

      if params[:unit]
        for key in [ :start_date, :end_date ] do
          if params[:unit][key].present?
            date_val = DateTime.parse(params[:unit][key])
            params[:unit][key] = date_val
          end
        end
      end
    end

    desc 'Get units related to the current user for admin purposes'
    params do
      optional :include_in_active, type: Boolean, desc: 'Include units that are not active'
    end
    get '/units' do
      unless authorise? current_user, User, :convene_units
        error!({ error: 'Unable to list units' }, 403)
      end

      # gets only the units the current user can "see"
      units = Unit.for_user_admin current_user

      units = units.where('active = true') unless params[:include_in_active]

      ActiveModel::ArraySerializer.new(units, each_serializer: ShallowUnitSerializer)
    end

    desc "Get a unit's details"
    get '/units/:id' do
      unit = Unit.find(params[:id])
      unless (authorise? current_user, unit, :get_unit) || (authorise? current_user, User, :admin_units)
        error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
      end
      #
      # Unit uses user from thread to limit exposure
      #
      Thread.current[:user] = current_user
      unit
    end

    desc 'Update unit'
    params do
      requires :id, type: Integer, desc: 'The unit id to update'
      requires :unit, type: Hash do
        optional :name, type: String
        optional :code, type: String
        optional :description, type: String
        optional :active, type: Boolean
        optional :teaching_period_id, type: Integer
        optional :start_date, type: Date
        optional :end_date, type: Date
        optional :main_convenor_id, type: Integer
        optional :auto_apply_extension_before_deadline, type: Boolean, desc: 'Indicates if extensions before the deadline should be automatically applied', default: true
        optional :send_notifications, type: Boolean, desc: 'Indicates if emails should be sent on updates each week', default: true

        mutually_exclusive :teaching_period_id,:start_date
        all_or_none_of :start_date, :end_date
      end
    end
    put '/units/:id' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update this unit' }, 403)
      end
      unit_parameters = ActionController::Parameters.new(params)
                                                    .require(:unit)
                                                    .permit(:name,
                                                            :code,
                                                            :description,
                                                            :start_date,
                                                            :end_date,
                                                            :teaching_period_id,
                                                            :active,
                                                            :main_convenor_id,
                                                            :auto_apply_extension_before_deadline,
                                                            :send_notifications
                                                          )

      if unit.teaching_period_id.present? && unit_parameters.key?(:start_date)
        unit.teaching_period = nil
      end

      unit.update!(unit_parameters)
      unit_parameters
    end

    desc 'Create unit'
    params do
      requires :unit, type: Hash do
        requires :name, type: String
        requires :code, type: String
        optional :description, type: String
        optional :active, type: Boolean
        optional :teaching_period_id, type: Integer
        optional :start_date, type: Date
        optional :end_date, type: Date
        optional :main_convenor_id, type: Integer
        optional :auto_apply_extension_before_deadline, type: Boolean, desc: 'Indicates if extensions before the deadline should be automatically applied', default: true
        optional :send_notifications, type: Boolean, desc: 'Indicates if emails should be sent on updates each week', default: true

        mutually_exclusive :teaching_period_id,:start_date
        mutually_exclusive :teaching_period_id,:end_date
      end
    end
    post '/units' do
      unless authorise? current_user, User, :create_unit
        error!({ error: 'Not authorised to create a unit' }, 403)
      end

      unit_parameters = ActionController::Parameters.new(params)
                                                    .require(:unit)
                                                    .permit(
                                                      :name,
                                                      :code,
                                                      :teaching_period_id,
                                                      :description,
                                                      :start_date,
                                                      :end_date,
                                                      :auto_apply_extension_before_deadline,
                                                      :send_notifications
                                                    )

      if unit_parameters[:description].nil?
        unit_parameters[:description] = unit_parameters[:name]
      end

      teaching_period_id = unit_parameters[:teaching_period_id]
      if teaching_period_id.blank?
        if unit_parameters[:start_date].nil?
          start_date = Date.parse('Monday')
          delta = start_date > Date.today ? 0 : 7
          unit_parameters[:start_date] = start_date + delta
        end

        if unit_parameters[:end_date].nil?
          unit_parameters[:end_date] = unit_parameters[:start_date] + 16.weeks
        end
      else
        if unit_parameters[:start_date].present? || unit_parameters[:end_date].present?
          error!({ error: 'Cannot specify dates as teaching period is selected' }, 403)
        end
      end

      unit = Unit.create!(unit_parameters)

      # Employ current user as convenor
      unit.employ_staff(current_user, Role.convenor)
      ShallowUnitSerializer.new(unit)
    end

    desc 'Rollover unit'
    params do
      optional :teaching_period_id
      optional :start_date
      optional :end_date

      exactly_one_of :teaching_period_id, :start_date
      all_or_none_of :start_date, :end_date
    end
    post '/units/:id/rollover' do
      unit = Unit.find(params[:id])

      if !(authorise?( current_user, User, :rollover) || authorise?( current_user, unit, :rollover_unit))
        error!({ error: 'Not authorised to rollover a unit' }, 403)
      end

      teaching_period_id = params[:teaching_period_id]

      if teaching_period_id.present?
        tp = TeachingPeriod.find(teaching_period_id)
        unit.rollover(tp, nil, nil)
      else
        unit.rollover(nil, params[:start_date], params[:end_date])
      end
    end

    desc 'Download the tasks that are awaiting feedback for a unit'
    get '/units/:id/feedback' do
      unit = Unit.find(params[:id])

      unless authorise? current_user, unit, :provide_feedback
        error!({ error: 'Not authorised to provide feedback for this unit' }, 403)
      end

      tasks = unit.tasks_awaiting_feedback(current_user)
      unit.tasks_as_hash(tasks)
    end

    desc 'Download the tasks that should be listed under the task inbox'
    get '/units/:id/tasks/inbox' do
      unit = Unit.find(params[:id])

      unless authorise? current_user, unit, :provide_feedback
        error!({ error: 'Not authorised to provide feedback for this unit' }, 403)
      end

      tasks = unit.tasks_for_task_inbox(current_user)
      unit.tasks_as_hash(tasks)
    end

    desc 'Download the grades for a unit'
    get '/units/:id/grades' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_grades
        error!({ error: 'Not authorised to download grades for this unit' }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv "
      env['api.format'] = :binary

      unit.student_grades_csv
    end

    desc 'Upload CSV of all the students in a unit'
    params do
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'CSV upload file.'
    end
    post '/csv/units/:id' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :upload_csv
        error!({ error: "Not authorised to upload CSV of students to #{unit.code}" }, 403)
      end

      unless params[:file].present?
        error!({ error: "No file uploaded" }, 403)
      end

      ensure_csv!(params[:file][:tempfile])

      # Actually import...
      unit.import_users_from_csv(params[:file][:tempfile])
    end

    desc 'Upload CSV with the students to un-enrol from the unit'
    params do
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'CSV upload file.'
    end
    post '/csv/units/:id/withdraw' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :upload_csv
        error!({ error: "Not authorised to upload CSV of students to #{unit.code}" }, 403)
      end

      unless params[:file].present?
        error!({ error: "No file uploaded" }, 403)
      end

      path = params[:file][:tempfile].path

      ensure_csv! path

      # Actually withdraw...
      unit.unenrol_users_from_csv(File.new(path))
    end

    desc 'Download CSV of all students in this unit'
    get '/csv/units/:id' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_unit_csv
        error!({ error: "Not authorised to download CSV of students enrolled in #{unit.code}" }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv "
      env['api.format'] = :binary
      unit.export_users_to_csv
    end

    desc 'Download CSV of all student tasks in this unit'
    get '/csv/units/:id/task_completion' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_unit_csv
        error!({ error: "Not authorised to download CSV of student tasks in #{unit.code}" }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-TaskCompletion.csv "
      env['api.format'] = :binary
      unit.task_completion_csv
    end

    desc 'Download the stats related to the number of students aiming for each grade'
    get '/units/:id/stats/student_target_grade' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_stats
        error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
      end

      unit.student_target_grade_stats
    end

    desc 'Download stats related to the status of students with tasks'
    get '/units/:id/stats/task_status_pct' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_stats
        error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
      end

      unit.task_status_stats
    end

    desc 'Download stats related to the number of completed tasks'
    get '/units/:id/stats/task_completion_stats' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_stats
        error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
      end

      unit.student_task_completion_stats
    end

    desc 'Download stats related to the number of tasks assessed by each tutor'
    get '/csv/units/:id/tutor_assessments' do
      unit = Unit.find(params[:id])
      unless authorise? current_user, unit, :download_stats
        error!({ error: "Not authorised to download stats of statistics for #{unit.code}" }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-TutorAssessments.csv "
      env['api.format'] = :binary

      unit.tutor_assessment_csv
    end
  end
end
