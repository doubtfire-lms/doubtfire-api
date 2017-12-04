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
        result.mark_as_read(current_user, project.unit)
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

        comments = task.all_comments.order('created_at ASC')
        result = comments.map do |c|
          {
            id: c.id,
            comment: c.comment,
            is_new: c.new_for?(current_user),
            author: {
              id: c.user.id,
              name: c.user.name,
              email: c.user.email
            },
            recipient: {
              id: c.recipient.id,
              name: c.recipient.name,
              email: c.user.email
            },
            created_at: c.created_at,
            recipient_read_time: c.time_read_by(c.recipient),
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
      task_comment = task.all_comments.find(params[:id])

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
      task_comment.mark_as_unread(current_user)
    end
  end
end
