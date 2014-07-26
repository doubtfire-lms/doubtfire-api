require 'grape'
require 'task_serializer'

module Api
  class Tasks < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    # desc "Get all the current user's tasks"
    # get '/tasks' do
    #   tasks = Task.for_user current_user
    # end

    # desc "Get task"
    # get '/tasks/:id' do
    #   task = Task.find(params[:id])
    #   #TODO: auth!

    #   if authorise? current_user, task, :get
    #     task
    #   else
    #     error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
    #   end
    # end

    desc "Update a task"
    params do
      requires :id, type: Integer, desc: 'The task id to update'
      requires :trigger, type: String, desc: 'New status'
    end
    put '/tasks/:id' do
      task = Task.find(params[:id])
      needsUploadDocs = task.upload_requirements.length > 0
      
      if authorise? current_user, task, :put
        # Check if they should be using portfolio_evidence api
        if needsUploadDocs && params[:trigger] == 'ready_to_mark'
          error!({"error" => "Cannot set this task status to ready to mark without uploading documents." }, 403)
        end
        task.trigger_transition( params[:trigger], current_user )
        TaskUpdateSerializer.new(task)
      else
        error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
      end 
    end
    
    desc "Upload CSV of tasks to the provided unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks to"
    end
    post '/csv/tasks' do
      unit = Unit.find(params[:unit_id])
      
      if not authorise? current_user, unit, :uploadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end
      
      # check mime is correct before uploading
      if not params[:file][:type] == "text/csv"
        error!({"error" => "File given is not a CSV file"}, 403)
      end
      
      # Actually import...
      unit.import_tasks_from_csv(params[:file][:tempfile])
    end
    
    desc "Download CSV of all tasks for the given unit"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to download tasks from"
    end
    get '/csv/tasks' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :downloadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Tasks.csv "
      env['api.format'] = :binary
      unit.task_definitions_csv
    end
    
  end
end


