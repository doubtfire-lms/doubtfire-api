require 'grape'

module Api
  class TaskComments < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a new comment to a task'
    params do
      requires :comment, type: String, desc: 'The comment text to add to the task'
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :make_submission
        error!({ error: 'Not authorised to create a comment for this task' }, 403)
      end

      task = project.task_for_task_definition(task_definition)
      result = task.add_comment current_user, params[:comment]

      if result.nil?
        error!({ error: 'No comment added. Comment duplicates last comment, so ignored.' }, 403)
      else
        result.create_comment_read_receipt_entry(current_user)
        result
      end
    end

    desc 'Get the comments related to a task'
    get '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get
        error!({ error: 'You cannot read the comments for this task' }, 403)
      end

      if project.has_task_for_task_definition? task_definition
        task = project.task_for_task_definition(task_definition)

        comments = task.all_comments(current_user).order('created_at ASC')
        result = comments.map do |c|
          {
            id: c.id,
            comment: c.comment,
            comment_by: c.user_id,
            is_new: c.new_for?(current_user),
            recipient: c.recipient.name,
            created_at: c.created_at,
            time_read: c.time_read_by(current_user)
          }
        end
        task.mark_comments_as_read(current_user, comments)
      else
        result = []
      end
      result
    end

    desc 'Delete a comment'
    delete '/projects/:project_id/task_def_id/:task_definition_id/comments/:id' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get
        error!({ error: 'You cannot read the comments for this task' }, 403)
      end

      task = project.task_for_task_definition(task_definition)
      task_comment = task.comments.find(params[:id])

      key = if current_user == task_comment.user
              :delete_own_comment
            else
              :delete_other_comment
            end

      unless authorise? current_user, task, key
        error!({ error: 'Not authorised to delete this comment' }, 403)
      end

      task_comment.destroy
    end

    desc 'Mark a comment as unread'
    post '/projects/:project_id/task_def_id/:task_definition_id/comments/:id' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :make_submission
        error!({ error: 'Not authorised to mark comment as unread' }, 403)
      end

      task = project.task_for_task_definition(task_definition)

      task_comment = task.comments.find(params[:id])
      task_comment.mark_as_unread(current_user, project.unit)
    end
  end
end
