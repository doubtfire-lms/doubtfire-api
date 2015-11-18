require 'grape'

module Api
  class TaskComments < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Add a new comment to a task"
    params do
      requires :comment,              type: String,   :desc => "The comment text to add to the task"
    end
    post '/tasks/:task_id/comments' do      
      task = Task.find(params[:task_id]) 
      
      if task.nil?
        error!({"error" => "Task not found"}, 404)
      end

      if not authorise? current_user, task, :make_submission
        error!({"error" => "Not authorised to create a comment for this task"}, 403)
      end

      result = task.add_comment current_user, params[:comment]
      if result.nil?
        error!({"error" => "No comment added. Comment duplicates last comment, so ignored."}, 403)
      else
        result
      end
    end
    
    desc "Get the comments related to a task"
    get '/tasks/:task_id/comments' do
      task = Task.find(params[:task_id]) 

      if not authorise? current_user, task, :get
        error!({"error" => "You cannot read the comments for this task"}, 403)
      end

      if task.nil?
        error!({"error" => "Task not found"}, 404)
      end      

      task.all_comments.order("created_at DESC")
    end

    desc "Delete a comment"
    delete '/tasks/:task_id/comments/:id' do
      task = Task.find(params[:task_id])       
      task_comment = TaskComment.find(params[:id])
      
      if task.nil? || task_comment.nil?
        error!({"error" => "Task or comment not found"}, 404)
      end

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


