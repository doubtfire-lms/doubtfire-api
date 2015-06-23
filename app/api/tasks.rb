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

      ActiveModel::ArraySerializer.new(Task.for_unit(unit.id).joins(project: :unit_role).select('tasks.*, unit_roles.tutorial_id as tutorial_id').where("projects.enrolled = true and tasks.task_status_id > 1 and unit_roles.tutorial_id is not null"), each_serializer: TaskStatSerializer)
    end

    desc "Get a similarity match for a given task"
    get '/tasks/:id/similarity/:count' do
      if not authenticated?
        error!({"error" => "Not authorised to download details for task '#{params[:id]}'"}, 401)
      end

        task = Task.find(params[:id])

        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to download details for task '#{params[:id]}'"}, 401)
        end

        match = params[:count].to_i % task.similar_to_count
        if match < 0
          error!({"error" => "Invalid match sequence, must be 0 or larger"}, 403)
        end

        output = FileHelper.path_to_plagarism_html(task.plagarism_match_links.order("created_at DESC").offset(match).first)

        if output.nil?
          error!({"error" => "No files to download"}, 403)
        end
        
        content_type "text/html"
        env['api.format'] = :binary
        File.read output
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
      optional :trigger, type: String, desc: 'New status'
      optional :include_in_portfolio, type: Boolean, desc: 'Include or exclude from portfolio'
    end
    put '/tasks/:id' do
      task = Task.find(params[:id])
      needsUploadDocs = task.upload_requirements.length > 0
      
      # check the user can put this task
      if authorise? current_user, task, :put
        # if trigger supplied...
        unless params[:trigger].nil?
          # Check if they should be using portfolio_evidence api
          if needsUploadDocs && params[:trigger] == 'ready_to_mark'
            error!({"error" => "Cannot set this task status to ready to mark without uploading documents." }, 403)
          end
          result = task.trigger_transition( params[:trigger], current_user )
          if result.nil? && task.task_definition.restrict_status_updates
            error!({"error" => "This task can only be updated by your tutor." }, 403)
          end
        end
        # if include in portfolio supplied
        unless params[:include_in_portfolio].nil?
          task.include_in_portfolio = params[:include_in_portfolio]
          task.save
        end

        TaskUpdateSerializer.new(task)
      else
        error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
      end 
    end
    
  end
end


