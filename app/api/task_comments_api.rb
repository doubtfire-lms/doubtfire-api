require 'grape'

class TaskCommentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Add a new comment to a task'
  params do
    optional :comment, type: String, desc: 'The comment text to add to the task'
    optional :attachment, type: File, desc: 'Image, sound, PDF or video comment file'
    optional :reply_to_id, type: Integer, desc: 'The comment to which this comment is replying'
  end
  post '/projects/:project_id/task_def_id/:task_definition_id/comments' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])

    unless authorise? current_user, project, :make_submission
      error!({ error: 'Not authorised to create a comment for this task' }, 403)
    end

    text_comment = params[:comment]
    attached_file = params[:attachment]
    reply_to_id = params[:reply_to_id]

    if attached_file.present?
      error!({ error: "Attachment is empty." }) unless File.size?(attached_file["tempfile"].path).present?
      error!({ error: "Attachment exceeds the maximum attachment size of 30MB." }) unless File.size?(attached_file["tempfile"].path) < 30_000_000
    end

    task = project.task_for_task_definition(task_definition)
    type_string = content_type.to_s

    if reply_to_id.present?
      originalTaskComment = TaskComment.find(reply_to_id)
      error!(error: 'You do not have permission to read the replied comment') unless authorise?(current_user, originalTaskComment.project, :get) || (task.group_task? && task.group.role_for(current_user) != nil)
      error!(error: 'Original comment is not in this task.') unless task.all_comments.find(reply_to_id).present?
    end

    logger.info("#{current_user.username} - added comment for task #{task.id} (#{task_definition.abbreviation})")

    if attached_file.nil? || attached_file.empty?
      error!({ error: 'Comment text is empty, unable to add new comment' }, 403) unless text_comment.present?
      result = task.add_text_comment(current_user, text_comment, reply_to_id)
    else
      unless FileHelper.accept_file(attached_file, 'comment attachment - TaskComment', 'comment_attachment')
        error!({ error: 'Please upload only images, audio or PDF documents' }, 403)
      end

      result = task.add_comment_with_attachment(current_user, attached_file, reply_to_id)
    end

    if result.nil?
      error!({ error: 'No comment added. Comment duplicates last comment, so ignored.' }, 403)
    else
      present result.serialize(current_user), with: Grape::Presenters::Presenter
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

      error!({ error: 'No attachment for this comment.' }, 404) unless %w(audio image pdf).include? comment.content_type

      error!({ error: 'File missing' }, 404) unless File.exist? comment.attachment_path

      # Set return content type
      content_type comment.attachment_mime_type

      env['api.format'] = :binary

      # mark as attachment
      if params[:as_attachment]
        header['Content-Disposition'] = "attachment; filename=#{comment.attachment_file_name}"
        header['Access-Control-Expose-Headers'] = 'Content-Disposition'
      end

      # Work out what part to return
      file_size = File.size(comment.attachment_path)
      begin_point = 0
      end_point = file_size - 1

      # Was it asked for just a part of the file?
      if request.headers['Range']
        # indicate partial content
        status 206

        # extract part desired from the content
        if request.headers['Range'] =~ /bytes\=(\d+)\-(\d*)/
          begin_point = Regexp.last_match(1).to_i
          end_point = Regexp.last_match(2).to_i if Regexp.last_match(2).present?
        end

        end_point = file_size - 1 unless end_point < file_size - 1
      end

      # Return the requested content
      content_length = end_point - begin_point + 1
      header['Content-Range'] = "bytes #{begin_point}-#{end_point}/#{file_size}"
      header['Content-Length'] = content_length.to_s
      header['Accept-Ranges'] = 'bytes'

      # Read the binary data and return
      IO.binread(comment.attachment_path, content_length, begin_point)
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
      # result = task.comments_for_user(current_user)
      # result.each do |d| end # cache results...

      # mark every comment type except for DiscussionComments so we don't mark it as read.
      comments_to_mark_as_read = comments.where("TYPE is null OR TYPE != 'DiscussionComment'")
      task.mark_comments_as_read(current_user, comments_to_mark_as_read)
    else
      result = []
    end
    present result, with: Grape::Presenters::Presenter
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

    present false
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

    present task_comment.serialize(current_user), with: Grape::Presenters::Presenter
  end
end
