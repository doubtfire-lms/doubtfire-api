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
      optional :type, type: Symbol, default: :text, values: [:text, :image, :audio, :video], desc: 'The type of comment to add to the task'
      optional :comment, type: String, desc: 'The comment text to add to the task'
      optional :attachment, type: Rack::Multipart::UploadedFile, desc: 'Image, sound, or video comment file'
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :make_submission
        error!({ error: 'Not authorised to create a comment for this task' }, 403)
      end

      content_type = params[:type].present? ? params[:type] : :text
      text_comment = params[:comment]
      attached_file = params[:attachment]

      error!({error: "Attachment exceeds the maximum attachment size of 10MB."}) unless File.size?(attached_file.tempfile.path) < 10_000_000

      task = project.task_for_task_definition(task_definition)
      type_string = content_type.to_s

      logger.info("#{current_user.username} - added comment - #{content_type} - for task #{task.id} (#{task_definition.abbreviation})")

      if content_type == :text
        error!({ error: "Comment text is empty, unable to add new comment"}, 403) unless text_comment.present?
        
        result = task.add_text_comment(current_user, text_comment, content_type)
      else
        error!({ error: "No file attached for this comment"}, 403) unless attached_file.present?
        unless FileHelper.accept_file(attached_file, "comment attachment - TaskComment", type_string)
          error!({ error: "File #{attached_file[:type]} attached is not a valid #{type_string} file" }, 403)
        end

        result = task.add_comment_with_attachment(current_user, attached_file, content_type)
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

        error!({error: 'No attachment for this comment.'}, 404) unless ["audio", "image"].include? comment.content_type

        mime_type = comment.attachment_mime_type
        # content_type comment.attachment.content_type
        content_type mime_type
        env['api.format'] = :binary
        if params[:as_attachment]
          header['Content-Disposition'] = "attachment; filename=#{comment.attachment_file_name}"
        end
        File.read(comment.attachment_path)
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
