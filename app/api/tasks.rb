require 'grape'
require 'task_serializer'

module Api
  class Tasks < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all the current user's tasks"
    params do
      requires :unit_id, type: Integer, desc: 'Unit to fetch the task details for'
    end
    get '/tasks' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :get_students
        error!({"error" => "You do not have permission to read these task details"}, 403)
      end

      ActiveModel::ArraySerializer.new(Task.for_unit(unit.id).joins(project: :unit_role).select('tasks.*, unit_roles.tutorial_id as tutorial_id').where("projects.enrolled = true and tasks.task_status_id > 1"), each_serializer: TaskStatSerializer)
    end

    # desc "Get task"
    # get '/tasks/:id' do
    #   task = Task.find(params[:id])

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
    
  end
end


