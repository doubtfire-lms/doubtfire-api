require 'grape'
require 'csv_helper'
require 'entities/unit_entity'

class UnitsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers
  helpers CsvHelper

  before do
    authenticated?

    if params[:unit]
      for key in [:start_date, :end_date] do
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
    unless authorise? current_user, User, :get_all_units
      error!({ error: 'Unable to list units' }, 403)
    end

    # gets only the units the current user can "see"
    units = Unit.for_user_admin(current_user)

    units = units.where('active = true') unless params[:include_in_active]

    present units, with: Entities::UnitEntity, user: current_user, summary_only: true, in_unit: true
  end

  desc "Get a unit's details"
  get '/units/:id' do
    unit = Unit.includes(
      { unit_roles: [:role, :user] },
      { task_definitions: :tutorial_stream },
      :learning_outcomes,
      { tutorial_streams: :activity_type },
      { tutorials: [:tutor, :tutorial_stream] },
      :tutorial_enrolments,
      :group_sets,
      :groups,
      :group_memberships
    ).find(params[:id])

    unless (authorise? current_user, unit, :get_unit) || (authorise? current_user, User, :admin_units)
      error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
    end

    #
    # Unit uses user from thread to limit exposure
    #
    my_role = unit.role_for(current_user)
    present unit, with: Entities::UnitEntity, my_role: my_role, in_unit: true
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
      optional :auto_apply_extension_before_deadline, type: Boolean, desc: 'Indicates if extensions before the deadline should be automatically applied'
      optional :send_notifications, type: Boolean, desc: 'Indicates if emails should be sent on updates each week'
      optional :enable_sync_timetable, type: Boolean, desc: 'Sync to timetable automatically if supported by deployment'
      optional :enable_sync_enrolments, type: Boolean, desc: 'Sync student enrolments automatically if supported by deployment'
      optional :draft_task_definition_id, type: Integer, desc: 'Indicates the ID of the task definition used as the "draft learning summary task"'
      optional :portfolio_auto_generation_date, type: Date, desc: 'Indicates a date where student portfolio will automatically compile'
      optional :allow_student_extension_requests, type: Boolean, desc: 'Can turn on/off student extension requests'
      optional :allow_student_change_tutorial, type: Boolean, desc: 'Can turn on/off student ability to change tutorials'
      optional :extension_weeks_on_resubmit_request, type: Integer, desc: 'Determines the number of weeks extension on a resubmit request'
      optional :overseer_image_id, type: Integer, desc: 'The id of the docker image used with '
      optional :assessment_enabled, type: Boolean

      mutually_exclusive :teaching_period_id, :start_date
      mutually_exclusive :teaching_period_id, :end_date
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
                                                          :send_notifications,
                                                          :enable_sync_timetable,
                                                          :enable_sync_enrolments,
                                                          :draft_task_definition_id,
                                                          :portfolio_auto_generation_date,
                                                          :allow_student_extension_requests,
                                                          :extension_weeks_on_resubmit_request,
                                                          :allow_student_change_tutorial,
                                                          :overseer_image_id,
                                                          :assessment_enabled)

    if unit.teaching_period_id.present? && (unit_parameters.key?(:start_date) || unit_parameters['teaching_period_id'] == -1)
      unit.teaching_period = nil
      unit_parameters.delete('teaching_period_id')
    end

    if unit_parameters[:draft_task_definition_id].present?
      # Ensure the task definition belongs to unit
      unless unit.task_definitions.exists?(unit_parameters[:draft_task_definition_id])
        error!({ error: 'Draft task definition ID does not belong to unit' }, 403)
      end

      # Validate that the task only has 1 upload requirement and it is a document
      task = TaskDefinition.find(unit_parameters[:draft_task_definition_id])
      if task.upload_requirements.length != 1 || task.upload_requirements.first['type'] != "document"
        error!({ error: 'Task definition should contain only a single document upload' }, 403)
      end
    end

    unit.update!(unit_parameters)
    present unit_parameters, with: Grape::Presenters::Presenter
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
      optional :main_convenor_user_id, type: Integer
      optional :auto_apply_extension_before_deadline, type: Boolean, desc: 'Indicates if extensions before the deadline should be automatically applied', default: true
      optional :send_notifications, type: Boolean, desc: 'Indicates if emails should be sent on updates each week', default: true
      optional :enable_sync_timetable, type: Boolean, desc: 'Sync to timetable automatically if supported by deployment', default: true
      optional :enable_sync_enrolments, type: Boolean, desc: 'Sync student enrolments automatically if supported by deployment', default: true
      optional :allow_student_extension_requests, type: Boolean, desc: 'Can turn on/off student extension requests', default: true
      optional :extension_weeks_on_resubmit_request, type: Integer, desc: 'Determines the number of weeks extension on a resubmit request', default: 1
      optional :portfolio_auto_generation_date, type: Date, desc: 'Indicates a date where student portfolio will automatically compile'
      optional :allow_student_change_tutorial, type: Boolean, desc: 'Can turn on/off student ability to change tutorials', default: true

      mutually_exclusive :teaching_period_id, :start_date
      mutually_exclusive :teaching_period_id, :end_date
      all_or_none_of :start_date, :end_date
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
                                                    :send_notifications,
                                                    :enable_sync_timetable,
                                                    :enable_sync_enrolments,
                                                    :allow_student_extension_requests,
                                                    :extension_weeks_on_resubmit_request,
                                                    :portfolio_auto_generation_date,
                                                    :allow_student_change_tutorial,
                                                  )

    # Identify main convenor - ensure they have the correct role
    main_convenor_user = unit_parameters[:main_convenor_user_id].present? ? User.find(unit_parameters[:main_convenor_user_id]) : current_user

    if main_convenor_user.blank?
      error!({ error: 'Main convenor user not found' }, 403)
    end

    unless authorise? main_convenor_user, User, :convene_units
      error!({ error: 'Main convenor is not authorised to manage units' }, 403)
    end

    if unit_parameters[:description].nil?
      unit_parameters[:description] = unit_parameters[:name]
    end

    teaching_period_id = unit_parameters[:teaching_period_id]
    if teaching_period_id.blank?
      if unit_parameters[:start_date].nil?
        start_date = Date.parse('Monday')
        delta = start_date > Time.zone.today ? 0 : 7
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

    # Employ the main convenor
    unit.employ_staff(main_convenor_user, Role.convenor)
    present unit, with: Entities::UnitEntity, my_role: Role.convenor, in_unit: true
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

    if !(authorise?(current_user, User, :rollover) || authorise?(current_user, unit, :rollover_unit))
      error!({ error: 'Not authorised to rollover a unit' }, 403)
    end

    teaching_period_id = params[:teaching_period_id]

    if teaching_period_id.present?
      tp = TeachingPeriod.find(teaching_period_id)
      result = unit.rollover(tp, nil, nil)
    else
      result = unit.rollover(nil, params[:start_date], params[:end_date])
    end

    my_role = result.role_for(current_user)

    present result, with: Entities::UnitEntity, my_role: my_role, user: current_user, in_unit: true
  end

  desc 'Download the tasks that are awaiting feedback for a unit'
  get '/units/:id/feedback' do
    unit = Unit.find(params[:id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to provide feedback for this unit' }, 403)
    end

    tasks = unit.tasks_awaiting_feedback(current_user)
    present unit.tasks_as_hash(tasks), with: Grape::Presenters::Presenter
  end

  desc 'Download the tasks that should be listed under the task inbox'
  get '/units/:id/tasks/inbox' do
    unit = Unit.find(params[:id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to provide feedback for this unit' }, 403)
    end

    tasks = unit.tasks_for_task_inbox(current_user)
    present unit.tasks_as_hash(tasks), with: Grape::Presenters::Presenter
  end

  desc 'Download the grades for a unit'
  get '/units/:id/grades' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_grades
      error!({ error: 'Not authorised to download grades for this unit' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary

    unit.student_grades_csv
  end

  desc 'Upload CSV of all the students in a unit'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
  end
  post '/csv/units/:id' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :upload_csv
      error!({ error: "Not authorised to upload CSV of students to #{unit.code}" }, 403)
    end

    if params[:file].blank?
      error!({ error: "No file uploaded" }, 403)
    end

    ensure_csv!(params[:file][:tempfile])

    # Actually import...
    unit.import_users_from_csv(params[:file][:tempfile])
  end

  desc 'Upload CSV with the students to un-enrol from the unit'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
  end
  post '/csv/units/:id/withdraw' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :upload_csv
      error!({ error: "Not authorised to upload CSV of students to #{unit.code}" }, 403)
    end

    if params[:file].blank?
      error!({ error: "No file uploaded" }, 403)
    end

    path = params[:file][:tempfile].path

    ensure_csv! path

    # Actually withdraw...
    response = unit.unenrol_users_from_csv(File.new(path))
    present response, with: Grape::Presenters::Presenter
  end

  desc 'Download CSV of all students in this unit'
  get '/csv/units/:id' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_unit_csv
      error!({ error: "Not authorised to download CSV of students enrolled in #{unit.code}" }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-Students.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
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
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-TaskCompletion.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.task_completion_csv
  end

  desc 'Download the stats related to the number of students aiming for each grade'
  get '/units/:id/stats/student_target_grade' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_stats
      error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
    end

    present unit.student_target_grade_stats, with: Grape::Presenters::Presenter
  end

  desc 'Download stats related to the status of students with tasks'
  get '/units/:id/stats/task_status_pct' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_stats
      error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
    end

    present unit.task_status_stats, with: Grape::Presenters::Presenter
  end

  desc 'Download stats related to the number of completed tasks'
  get '/units/:id/stats/task_completion_stats' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_stats
      error!({ error: "Not authorised to download stats of student tasks in #{unit.code}" }, 403)
    end

    present unit.student_task_completion_stats, with: Grape::Presenters::Presenter
  end

  desc 'Download stats related to the number of tasks assessed by each tutor'
  get '/csv/units/:id/tutor_assessments' do
    unit = Unit.find(params[:id])
    unless authorise? current_user, unit, :download_stats
      error!({ error: "Not authorised to download stats of statistics for #{unit.code}" }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-TutorAssessments.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary

    unit.tutor_assessment_csv
  end
end
