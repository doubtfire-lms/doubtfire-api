require 'grape'
require 'task_serializer'
require 'mime-check-helpers'

module Api
  class TaskDefinitionsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers FileHelper
    helpers MimeCheckHelpers

    before do
      authenticated?
    end

    desc 'Add a new task definition to the given unit'
    params do
      requires :task_def, type: Hash do
        optional :tutorial_stream_abbr,     type: String,   desc: 'The abbreviation of tutorial stream'
        requires :name,                     type: String,   desc: 'The name of this task def'
        requires :description,              type: String,   desc: 'The description of this task def'
        requires :weighting,                type: Integer,  desc: 'The weighting of this task'
        requires :target_grade,             type: Integer,  desc: 'Minimum grade for task'
        optional :group_set_id,             type: Integer,  desc: 'Related group set'
        requires :start_date,               type: Date,     desc: 'The date when the task should be started'
        requires :target_date,              type: Date,     desc: 'The date when the task is due'
        optional :due_date,                 type: Date,     desc: 'The deadline date'
        requires :abbreviation,             type: String,   desc: 'The abbreviation of the task'
        requires :restrict_status_updates,  type: Boolean,  desc: 'Restrict updating of the status to staff'
        optional :upload_requirements,      type: String,   desc: 'Task file upload requirements'
        optional :plagiarism_checks,        type: String,   desc: 'The list of checks to perform'
        requires :plagiarism_warn_pct,      type: Integer,  desc: 'The percent at which to record and warn about plagiarism'
        requires :is_graded,                type: Boolean,  desc: 'Whether or not this task definition is a graded task'
        requires :max_quality_pts,          type: Integer,  desc: 'A range for quality points when quality is assessed'
      end
    end
    post '/units/:unit_id/task_definitions/' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to create a task definition of this unit' }, 403)
      end

      params[:task_def][:upload_requirements] = '[]' if params[:task_def][:upload_requirements].nil?

      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :name,
                                                  :description,
                                                  :weighting,
                                                  :target_grade,
                                                  :start_date,
                                                  :target_date,
                                                  :due_date,
                                                  :abbreviation,
                                                  :restrict_status_updates,
                                                  :upload_requirements,
                                                  :plagiarism_checks,
                                                  :plagiarism_warn_pct,
                                                  :is_graded,
                                                  :max_quality_pts
                                                )

      task_params[:unit_id] = unit.id

      task_def = TaskDefinition.new(task_params)

      # Set the tutorial stream
      tutorial_stream_abbr = params[:task_def][:tutorial_stream_abbr]
      unless tutorial_stream_abbr.nil?
        tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: tutorial_stream_abbr)
        task_def.tutorial_stream = tutorial_stream
      end

      #
      # Link in group set if specified
      #
      if params[:task_def][:group_set_id] && params[:task_def][:group_set_id] >= 0
        gs = GroupSet.find(params[:task_def][:group_set_id])
        task_def.group_set = gs if gs.unit == unit
      end

      task_def.save!
      task_def
    end

    desc 'Edits the given task definition'
    params do
      requires :id, type: Integer, desc: 'The task id to edit'
      requires :task_def, type: Hash do
        optional :tutorial_stream_abbr,     type: String,   desc: 'The abbreviation of the tutorial stream'
        optional :name,                     type: String,   desc: 'The name of this task def'
        optional :description,              type: String,   desc: 'The description of this task def'
        optional :weighting,                type: Integer,  desc: 'The weighting of this task'
        optional :target_grade,             type: Integer,  desc: 'Target grade for task'
        optional :group_set_id,             type: Integer,  desc: 'Related group set'
        optional :start_date,               type: Date,     desc: 'The date when the task should be started'
        optional :target_date,              type: Date,     desc: 'The date when the task is due'
        optional :due_date,                 type: Date,     desc: 'The deadline date'
        optional :abbreviation,             type: String,   desc: 'The abbreviation of the task'
        optional :restrict_status_updates,  type: Boolean,  desc: 'Restrict updating of the status to staff'
        optional :upload_requirements,      type: String,   desc: 'Task file upload requirements'
        optional :plagiarism_checks,        type: String,   desc: 'The list of checks to perform'
        optional :plagiarism_warn_pct,      type: Integer,  desc: 'The percent at which to record and warn about plagiarism'
        optional :is_graded,                type: Boolean,  desc: 'Whether or not this task definition is a graded task'
        optional :max_quality_pts,          type: Integer,  desc: 'A range for quality points when quality is assessed'
      end
    end
    put '/units/:unit_id/task_definitions/:id' do
      unit = Unit.find(params[:unit_id])
      task_def = unit.task_definitions.find(params[:id])

      unless authorise? current_user, task_def.unit, :add_task_def
        error!({ error: 'Not authorised to create a task definition of this unit' }, 403)
      end

      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :name,
                                                  :description,
                                                  :weighting,
                                                  :target_grade,
                                                  :start_date,
                                                  :target_date,
                                                  :due_date,
                                                  :abbreviation,
                                                  :restrict_status_updates,
                                                  :upload_requirements,
                                                  :plagiarism_checks,
                                                  :plagiarism_warn_pct,
                                                  :is_graded,
                                                  :max_quality_pts
                                                )

      task_def.update!(task_params)

      # Set the tutorial stream
      tutorial_stream_abbr = params[:task_def][:tutorial_stream_abbr]
      unless tutorial_stream_abbr.nil?
        tutorial_stream = task_def.unit.tutorial_streams.find_by!(abbreviation: tutorial_stream_abbr)
        task_def.tutorial_stream = tutorial_stream
        task_def.save!
      end

      #
      # Link in group set if specified
      #
      if params[:task_def][:group_set_id]
        if params[:task_def][:group_set_id] >= 0
          gs = GroupSet.find(params[:task_def][:group_set_id])
          if gs.unit == task_def.unit
            task_def.group_set = gs
            task_def.save!
          end
        else
          task_def.group_set = nil
          task_def.save!
        end
      end

      task_def
    end

    desc 'Upload CSV of task definitions to the provided unit'
    params do
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'CSV upload file.'
      requires :unit_id, type: Integer, desc: 'The unit to upload tasks to'
    end
    post '/csv/task_definitions' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :upload_csv
        error!({ error: 'Not authorised to upload CSV of tasks' }, 403)
      end

      unless params[:file].present?
        error!({ error: "No file uploaded" }, 403)
      end

      path = params[:file][:tempfile].path

      # check mime is correct before uploading
      ensure_csv!(path)

      # Actually import...
      unit.import_tasks_from_csv(File.new(path))
    end

    desc 'Download CSV of all task definitions for the given unit'
    params do
      requires :unit_id, type: Integer, desc: 'The unit to download tasks from'
    end
    get '/csv/task_definitions' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :download_unit_csv
        error!({ error: 'Not authorised to download CSV of tasks' }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Tasks.csv "
      env['api.format'] = :binary
      unit.task_definitions_csv
    end

    desc 'Delete a task definition'
    delete '/units/:unit_id/task_definitions/:id' do
      task_def = TaskDefinition.find(params[:id])

      unless authorise? current_user, task_def.unit, :add_task_def
        error!({ error: 'Not authorised to delete a task definition of this unit' }, 403)
      end

      task_def.destroy
    end

    desc 'Upload the task sheet for a given task'
    params do
      requires :unit_id, type: Integer, desc: 'The related unit'
      requires :task_def_id, type: Integer, desc: 'The related task definition'
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'The task sheet pdf'
    end
    post '/units/:unit_id/task_definitions/:task_def_id/task_sheet' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to upload tasks of unit' }, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      file = params[:file]

      unless FileHelper.accept_file(file, 'task sheet', 'document')
        error!({ error: "'#{file.name}' is not a valid #{file.type} file" }, 403)
      end

      # Actually import...
      task_def.add_task_sheet(file[:tempfile].path)
    end

    desc 'Remove the task sheet for a given task'
    params do
      requires :unit_id, type: Integer, desc: 'The related unit'
      requires :task_def_id, type: Integer, desc: 'The related task definition'
    end
    delete '/units/:unit_id/task_definitions/:task_def_id/task_sheet' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to remove task sheets of unit' }, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      # Actually delete...
      task_def.remove_task_sheet()
      task_def
    end

    desc 'Upload the task resources for a given task'
    params do
      requires :unit_id, type: Integer, desc: 'The related unit'
      requires :task_def_id, type: Integer, desc: 'The related task definition'
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'The task resources zip'
    end
    post '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to upload tasks of unit' }, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      unless params[:file].present?
        error!({ error: "No file uploaded" }, 403)
      end

      file_path = params[:file][:tempfile].path

      check_mime_against_list! file_path, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

      # Actually import...
      task_def.add_task_resources(file_path)
    end

    desc 'Remove the task resources for a given task'
    params do
      requires :unit_id, type: Integer, desc: 'The related unit'
      requires :task_def_id, type: Integer, desc: 'The related task definition'
    end
    delete '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to remove task resources of unit' }, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      # Actually remove...
      task_def.remove_task_resources
      task_def
    end

    desc 'Upload a zip file containing the task pdfs for a given task'
    params do
      requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'batch file upload'
    end
    post '/units/:unit_id/task_definitions/task_pdfs' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised to upload tasks of unit' }, 403)
      end

      unless params[:file].present?
        error!({ error: "No file uploaded" }, 403)
      end

      file = params[:file][:tempfile].path

      check_mime_against_list! file, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

      # Actually import...
      unit.import_task_files_from_zip file
    end

    desc 'Download the tasks related to a task definition'
    params do
      requires :unit_id, type: Integer, desc: 'The unit containing the task definition'
      requires :task_def_id, type: Integer, desc: "The task definition's id"
    end
    get '/units/:unit_id/task_definitions/:task_def_id/tasks' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :provide_feedback
        error!({ error: 'Not authorised to access tasks for this unit' }, 403)
      end

      # Which task definition is this for
      task_def = unit.task_definitions.find(params[:task_def_id])

      # What stream does this relate to?
      stream = task_def.tutorial_stream

      subquery = unit.
        tutorial_enrolments.
        joins(:tutorial).
        where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL', sid: (stream.present? ? stream.id : nil)).
        select('tutorials.tutorial_stream_id as tutorial_stream_id', 'tutorials.id as tutorial_id', 'project_id').to_sql

      unit.student_tasks.
        joins(:project).
        joins(:task_status).
        joins("LEFT OUTER JOIN (#{subquery}) as sq ON sq.project_id = projects.id").
        select('sq.tutorial_stream_id as tutorial_stream_id', 'sq.tutorial_id as tutorial_id', 'project_id', 'tasks.id as id', 'task_definition_id', 'task_statuses.id as status_id', 'completion_date', 'times_assessed', 'submission_date', 'grade').
        where('task_definition_id = :id', id: params[:task_def_id]).
        map do |t|
        {
          project_id: t.project_id,
          id: t.id,
          task_definition_id: t.task_definition_id,
          tutorial_id: t.tutorial_id,
          tutorial_stream_id: t.tutorial_stream_id,
          status: TaskStatus.id_to_key(t.status_id),
          completion_date: t.completion_date,
          submission_date: t.submission_date,
          times_assessed: t.times_assessed,
          similar_to_count: t.similar_to_count,
          grade: t.grade
        }
      end
    end

    desc 'Download the task sheet containing the details related to performing that task'
    params do
      requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
      requires :task_def_id, type: Integer, desc: 'The task definition to get the pdf of'
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
    end
    get '/units/:unit_id/task_definitions/:task_def_id/task_pdf' do
      unit = Unit.find(params[:unit_id])
      task_def = unit.task_definitions.find(params[:task_def_id])

      unless authorise? current_user, unit, :get_unit
        error!({ error: 'Not authorised to download task details of unit' }, 403)
      end

      if task_def.has_task_sheet?
        path = task_def.task_sheet
        filename = "#{task_def.unit.code}-#{task_def.abbreviation}.pdf"
      else
        path = Rails.root.join('public', 'resources', 'FileNotFound.pdf')
        filename = "FileNotFound.pdf"
      end

      if params[:as_attachment]
        header['Content-Disposition'] = "attachment; filename=#{filename}"
      end

      content_type 'application/pdf'
      env['api.format'] = :binary
      File.read(path)
    end

    desc 'Download the task resources'
    params do
      requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
      requires :task_def_id, type: Integer, desc: 'The task definition to get the pdf of'
    end
    get '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
      unit = Unit.find(params[:unit_id])
      task_def = unit.task_definitions.find(params[:task_def_id])

      unless authorise? current_user, unit, :get_unit
        error!({ error: 'Not authorised to download task details of unit' }, 403)
      end

      if task_def.has_task_resources?
        path = task_def.task_resources
        content_type 'application/octet-stream'
        header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}-resources.zip"
      else
        path = Rails.root.join('public', 'resources', 'FileNotFound.pdf')
        content_type 'application/pdf'
        header['Content-Disposition'] = 'attachment; filename=FileNotFound.pdf'
      end

      env['api.format'] = :binary
      File.read(path)
    end
  end
end
