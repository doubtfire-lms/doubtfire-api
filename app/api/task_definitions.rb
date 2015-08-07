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
      group :task_def do
        requires :unit_id,              type: Integer,  :desc => "The unit to create the new task def for"
        requires :name,                 type: String,   :desc => "The name of this task def"
        requires :description,          type: String,   :desc => "The description of this task def"
        requires :weighting,            type: Integer,  :desc => "The weighting of this task"
        requires :target_grade,         type: Integer,  :desc => "Minimum grade for task"
        optional :group_set_id,         type: Integer,  :desc => "Related group set"
        requires :target_date,          type: Date,     :desc => "The date when the task is due"
        requires :abbreviation,         type: String,   :desc => "The abbreviation of the task"
        requires :restrict_status_updates, type: Boolean,  :desc => "Restrict updating of the status to staff"
        optional :upload_requirements,  type: String,   :desc => "Task file upload requirements"
        optional :plagiarism_checks,    type: String,   :desc => "The list of checks to perform"
        requires :plagiarism_warn_pct,  type: Integer,  :desc => "The percent at which to record and warn about plagiarism"
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
                                                  :target_date,        
                                                  :abbreviation,
                                                  :restrict_status_updates,
                                                  :upload_requirements,
                                                  :plagiarism_checks,
                                                  :plagiarism_warn_pct
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

      unit.add_new_task_def(task_def)
      task_def
    end
    
    desc "Edits the given task definition"
    params do
      requires :id,                     type: Integer,  :desc => "The task id to edit"
      group :task_def do
        optional :unit_id,              type: Integer,  :desc => "The unit to create the new task def for"
        optional :name,                 type: String,   :desc => "The name of this task def"
        optional :description,          type: String,   :desc => "The description of this task def"
        optional :weighting,            type: Integer,  :desc => "The weighting of this task"
        optional :target_grade,         type: Integer,  :desc => "Target grade for task"
        optional :group_set_id,         type: Integer,  :desc => "Related group set"
        optional :target_date,          type: Date,     :desc => "The date when the task is due"
        optional :abbreviation,         type: String,   :desc => "The abbreviation of the task"
        optional :restrict_status_updates,    type: Boolean,  :desc => "Restrict updating of the status to staff"
        optional :upload_requirements,  type: String,   :desc => "Task file upload requirements"
        optional :plagiarism_checks,    type: String,   :desc => "The list of checks to perform"
        requires :plagiarism_warn_pct,  type: Integer,  :desc => "The percent at which to record and warn about plagiarism"
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
                                                  :target_date,        
                                                  :abbreviation,
                                                  :restrict_status_updates,
                                                  :upload_requirements,
                                                  :plagiarism_checks,
                                                  :plagiarism_warn_pct
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
      
      if not authorise? current_user, unit, :uploadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
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

      if not authorise? current_user, unit, :downloadCSV
        error!({"error" => "Not authorised to upload CSV of tasks"}, 403)
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

      content_type "application/pdf"
      header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}.pdf"
      env['api.format'] = :binary
      File.read(unit.path_to_task_pdf(task_def))
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

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}-resources.zip"
      env['api.format'] = :binary
      File.read(unit.path_to_task_resources(task_def))
    end
  end
end


