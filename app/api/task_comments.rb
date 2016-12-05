require 'grape'

module Api
  class TaskComments < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Add a new comment to a task"
    params do
      requires :comment,              type: String,   :desc => "The comment text to add to the task"
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      if not authorise? current_user, project, :make_submission
        error!({"error" => "Not authorised to create a comment for this task"}, 403)
      end

      task = project.task_for_task_definition(task_definition)

      result = task.add_comment current_user, params[:comment]
      if result.nil?
        error!({"error" => "No comment added. Comment duplicates last comment, so ignored."}, 403)
      else
        result
      end
    end
    
    desc "Get the comments related to a task"
    get '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      if not authorise? current_user, project, :get
        error!({"error" => "You cannot read the comments for this task"}, 403)
      end

      if project.has_task_for_task_definition? task_definition
        task = project.task_for_task_definition(task_definition)

        task.all_comments.order("created_at DESC")
      else
        []
      end
    end

    desc "Delete a comment"
    delete '/projects/:project_id/task_def_id/:task_definition_id/comments/:id' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])
      
      if not authorise? current_user, project, :get
        error!({"error" => "You cannot read the comments for this task"}, 403)
      end

      task = project.task_for_task_definition(task_definition)
      task_comment = task.comments.find(params[:id])

      if current_user == task_comment.user
        key = :delete_own_comment
      else
        key = :delete_other_comment
      end

      if not authorise? current_user, task, key
        error!({"error" => "Not authorised to delete this comment"}, 403)
      end

      task_comment.destroy()
    end

  end
end


