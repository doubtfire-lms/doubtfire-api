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
      requires :type, type: Symbol, default: :text, values: [:text, :image, :audio, :video], desc: 'The type of comment to add to the task'
      optional :comment, type: String, desc: 'The comment text to add to the task'
      optional :attachment, type: Rack::Multipart::UploadedFile, desc: 'Image, sound, or video comment file'
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :make_submission
        error!({ error: 'Not authorised to create a comment for this task' }, 403)
      end

      content_type = params[:type]
      text_comment = params[:comment]
      attachment_comment = params[:attachment]

      task = project.task_for_task_definition(task_definition)
      type_string = content_type.to_s

      if content_type == :text
        if text_comment.nil?
          error!({ error: "text field is empty"}, 403)
        end
        result = task.add_text_comment(current_user, text_comment, content_type)
      else
        if attachment_comment.nil?
          error!({ error: "No file attached"}, 403)
        else
          unless FileHelper.accept_file(attachment_comment, "comment attachment - TaskComment", type_string)
            error!({ error: "File #{attachment_comment[:type]} attached is not a valid #{type_string} file" }, 403)
          end
        end
        result = task.add_comment_with_attachment(current_user, attachment_comment, content_type)
      end

      if result.nil?
        error!({ error: 'No comment added. Comment duplicates last comment, so ignored.' }, 403)
      else
        result.mark_as_read(current_user, project.unit)
        result.serialize(current_user)
      end
    end

    desc 'Get an attachment related to a task comment'
    params do
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
    end
    get '/projects/:project_id/task_def_id/:task_definition_id/comments/:id' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get
        error!({ error: 'You cannot read the comments for this task' }, 403)
      end

      if project.has_task_for_task_definition? task_definition
        task = project.task_for_task_definition(task_definition)

        comment = task.comments.find(params[:id])

        content_type comment.attachment.content_type
        env['api.format'] = :binary
        if params[:as_attachment]
          header['Content-Disposition'] = "attachment; filename=#{comment.attachment_file_name}"
        end
        File.read(comment.attachment.path)
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
        result = comments.map { |c| c.serialize(current_user) }          
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
