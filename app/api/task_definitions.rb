require 'grape'
require 'task_serializer'
require 'mime-check-helpers'

module Api
  class TaskDefinitions < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers
    helpers FileHelper
    helpers MimeCheckHelpers

    before do
      authenticated?
    end

    desc "Add a new task definition to the given unit"
    params do
      requires :task_def, type: Hash do
        requires :unit_id,                  type: Integer,  :desc => "The unit to create the new task def for"
        requires :name,                     type: String,   :desc => "The name of this task def"
        requires :description,              type: String,   :desc => "The description of this task def"
        requires :weighting,                type: Integer,  :desc => "The weighting of this task"
        requires :target_grade,             type: Integer,  :desc => "Minimum grade for task"
        optional :group_set_id,             type: Integer,  :desc => "Related group set"
        requires :start_date,               type: Date,     :desc => "The date when the task should be started"
        requires :target_date,              type: Date,     :desc => "The date when the task is due"
        optional :due_date,                 type: Date,     :desc => "The deadline date"
        requires :abbreviation,             type: String,   :desc => "The abbreviation of the task"
        requires :restrict_status_updates,  type: Boolean,  :desc => "Restrict updating of the status to staff"
        optional :upload_requirements,      type: String,   :desc => "Task file upload requirements"
        optional :plagiarism_checks,        type: String,   :desc => "The list of checks to perform"
        requires :plagiarism_warn_pct,      type: Integer,  :desc => "The percent at which to record and warn about plagiarism"
        requires :is_graded,                type: Boolean,  :desc => "Whether or not this task definition is a graded task"
      end
    end
    post '/task_definitions/' do
      unit = Unit.find(params[:task_def][:unit_id])
      if not authorise? current_user, unit, :add_task_def
        error!({"error" => "Not authorised to create a task definition of this unit"}, 403)
      end

      params[:task_def][:upload_requirements] = "[]" if params[:task_def][:upload_requirements].nil?;

      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :unit_id,
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
                                                  :is_graded
                                                )

      task_def = TaskDefinition.new(task_params)

      #
      # Link in group set if specified
      #
      if params[:task_def][:group_set_id] && params[:task_def][:group_set_id] >= 0
        gs = GroupSet.find(params[:task_def][:group_set_id])
        if gs.unit == unit
          task_def.group_set = gs
        end
      end

      task_def.save!
      task_def
    end

    desc "Edits the given task definition"
    params do
      requires :id,                     type: Integer,  :desc => "The task id to edit"
      requires :task_def, type: Hash do
        optional :unit_id,                  type: Integer,  :desc => "The unit to create the new task def for"
        optional :name,                     type: String,   :desc => "The name of this task def"
        optional :description,              type: String,   :desc => "The description of this task def"
        optional :weighting,                type: Integer,  :desc => "The weighting of this task"
        optional :target_grade,             type: Integer,  :desc => "Target grade for task"
        optional :group_set_id,             type: Integer,  :desc => "Related group set"
        optional :start_date,               type: Date,     :desc => "The date when the task should be started"
        optional :target_date,              type: Date,     :desc => "The date when the task is due"
        optional :due_date,                 type: Date,     :desc => "The deadline date"
        optional :abbreviation,             type: String,   :desc => "The abbreviation of the task"
        optional :restrict_status_updates,  type: Boolean,  :desc => "Restrict updating of the status to staff"
        optional :upload_requirements,      type: String,   :desc => "Task file upload requirements"
        optional :plagiarism_checks,        type: String,   :desc => "The list of checks to perform"
        optional :plagiarism_warn_pct,      type: Integer,  :desc => "The percent at which to record and warn about plagiarism"
        optional :is_graded,                type: Boolean,  :desc => "Whether or not this task definition is a graded task"
      end
    end
    put '/task_definitions/:id' do
      task_def = TaskDefinition.find(params[:id])

      if not authorise? current_user, task_def.unit, :add_task_def
        error!({"error" => "Not authorised to create a task definition of this unit"}, 403)
      end

      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :unit_id,
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
                                                  :is_graded
                                                )

      task_def.update!(task_params)
      #
      # Link in group set if specified
      #
      if params[:task_def][:group_set_id]
        if params[:task_def][:group_set_id] >= 0
          gs = GroupSet.find(params[:task_def][:group_set_id])
          if gs.unit == task_def.unit
            task_def.group_set = gs
            task_def.save
          end
        else
          task_def.group_set = nil
          task_def.save
        end
      end

      task_def
    end

    desc "Upload CSV of task definitions to the provided unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks to"
    end
    post '/csv/task_definitions' do
      # check mime is correct before uploading
      ensure_csv!(params[:file][:tempfile])

      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :upload_csv
        error!({"error" => "Not authorised to upload CSV of tasks"}, 403)
      end

      # Actually import...
      unit.import_tasks_from_csv(params[:file][:tempfile])
    end

    desc "Download CSV of all task definitions for the given unit"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to download tasks from"
    end
    get '/csv/task_definitions' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :download_unit_csv
        error!({"error" => "Not authorised to download CSV of tasks"}, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Tasks.csv "
      env['api.format'] = :binary
      unit.task_definitions_csv
    end

    desc "Delete a task definition"
    delete '/task_definitions/:id' do
      task_def = TaskDefinition.find(params[:id])

      if not authorise? current_user, task_def.unit, :add_task_def
        error!({"error" => "Not authorised to delete a task definition of this unit"}, 403)
      end

      task_def.destroy()
    end

    desc "Upload the task sheet for a given task"
    params do
      requires :unit_id, type: Integer, :desc => "The related unit"
      requires :task_def_id, type: Integer, :desc => "The related task definition"
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "The task sheet pdf"
    end
    post '/units/:unit_id/task_definitions/:task_def_id/task_sheet' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :add_task_def
        error!({"error" => "Not authorised to upload tasks of unit"}, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      file = params[:file]

      if not FileHelper.accept_file(file, 'task sheet', 'document')
        error!({"error" => "'#{file.name}' is not a valid #{file.type} file"}, 403)
      end

      # Actually import...
      task_def.add_task_sheet(file[:tempfile].path)
    end

    desc "Upload the task resources for a given task"
    params do
      requires :unit_id, type: Integer, :desc => "The related unit"
      requires :task_def_id, type: Integer, :desc => "The related task definition"
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "The task resources zip"
    end
    post '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :add_task_def
        error!({"error" => "Not authorised to upload tasks of unit"}, 403)
      end

      task_def = unit.task_definitions.find(params[:task_def_id])

      file_path = params[:file][:tempfile].path

      check_mime_against_list! file_path, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

      # Actually import...
      task_def.add_task_resources(file_path)
    end

    desc "Upload a zip file containing the task pdfs for a given task"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks for"
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "batch file upload"
    end
    post '/units/:unit_id/task_definitions/task_pdfs' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :add_task_def
        error!({"error" => "Not authorised to upload tasks of unit"}, 403)
      end

      file = params[:file][:tempfile].path

      check_mime_against_list! file, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

      # Actually import...
      unit.import_task_files_from_zip file
    end

    desc "Download the tasks related to a task definition"
    params do
      requires :unit_id, type: Integer, :desc => "The unit containing the task definition"
      requires :task_def_id, type: Integer, :desc => "The task definition's id"
    end
    get '/units/:unit_id/task_definitions/:task_def_id/tasks' do
      unit = Unit.find(params[:unit_id])
      if not authorise? current_user, unit, :provide_feedback
        error!({"error" => "Not authorised to access tasks for this unit" }, 403)
      end

      unit.student_tasks.
        joins(:project).
        joins(:task_status).
        select("projects.tutorial_id as tutorial_id", "project_id", "tasks.id as id", "task_definition_id", "task_statuses.name as status_name", "completion_date", "times_assessed", "submission_date").
        where("task_definition_id = :id", id: params[:task_def_id]).
        map { |t|
        {
          project_id: t.project_id,
          id: t.id,
          task_definition_id: t.task_definition_id,
          tutorial_id: t.tutorial_id,
          status: TaskStatus.status_key_for_name(t.status_name),
          completion_date: t.completion_date,
          submission_date: t.submission_date,
          times_assessed: t.times_assessed
        }
      }
    end

    desc "Download the task pdf"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks for"
      requires :task_def_id, type: Integer, :desc => "The task definition to get the pdf of"
    end
    get '/units/:unit_id/task_definitions/:task_def_id/task_pdf' do
      unit = Unit.find(params[:unit_id])
      task_def = unit.task_definitions.find(params[:task_def_id])

      if not authorise? current_user, unit, :get_unit
        error!({"error" => "Not authorised to download task details of unit"}, 403)
      end

      if task_def.has_task_pdf?
        header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}.pdf"
        path = unit.path_to_task_pdf(task_def)
      else
        path = Rails.root.join("public", "resources", "FileNotFound.pdf")
        header['Content-Disposition'] = "attachment; filename=FileNotFound.pdf"
      end

      content_type "application/pdf"
      env['api.format'] = :binary
      File.read(path)
    end

    desc "Download the task resources"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks for"
      requires :task_def_id, type: Integer, :desc => "The task definition to get the pdf of"
    end
    get '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
      unit = Unit.find(params[:unit_id])
      task_def = unit.task_definitions.find(params[:task_def_id])

      if not authorise? current_user, unit, :get_unit
        error!({"error" => "Not authorised to download task details of unit"}, 403)
      end

      if task_def.has_task_resources?
        path = unit.path_to_task_resources(task_def)
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}-resources.zip"
      else
        path = Rails.root.join("public", "resources", "FileNotFound.pdf")
        content_type "application/pdf"
        header['Content-Disposition'] = "attachment; filename=FileNotFound.pdf"
      end

      env['api.format'] = :binary
      File.read(path)
    end
  end
end
