# frozen_string_literal: true
require 'grape'

module Api
  class DiscussionComments < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a new discussion comment to a task'
    params do
      requires :attachments, type: Array do
        requires type: Rack::Multipart::UploadedFile, desc: 'audio prompts.'
      end
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/discussion_comments' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :create_discussion
        # error!({ error: 'Not authorised to create a discussion comment for this task' }, 403)
      end

      attached_files = params[:attachments]

      for attached_file in attached_files do
        if attached_file.present?
          error!(error: 'Attachment is empty.') unless File.size?(attached_file.tempfile.path).present?
          error!(error: 'Attachment exceeds the maximum attachment size of 30MB.') unless File.size?(attached_file.tempfile.path) < 30_000_000
        end
      end

      task = project.task_for_task_definition(task_definition)
      type_string = content_type.to_s

      logger.info("#{current_user.username} - added discussion comment for task #{task.id} (#{task_definition.abbreviation})")

      if attached_files.nil? || attached_files.empty?
        error!({ error: 'Audio prompts are empty, unable to add new discussion comment' }, 403)
      end

      result = task.add_discussion_comment(current_user, attached_files)
      result.mark_as_read(current_user, project.unit)
      DiscussionCommentSerializer.new(result)
    end

    desc 'Get a discussion comment prompt'
    params do
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
    end
    get '/projects/:project_id/task_def_id/:task_definition_id/comments/:task_comment_id/discussion_comment/prompt_number/:prompt_number' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])
      prompt_number = params[:prompt_number]

      task = project.task_for_task_definition(task_definition)

      unless authorise? current_user, project, :get_discussion
        # error!({ error: 'You cannot get this discussion prompt' }, 403)
      end

      if project.has_task_for_task_definition? task_definition
        task = project.task_for_task_definition(task_definition)
        discussion_comment = task.all_comments.find(params[:task_comment_id]).becomes(DiscussionComment)
        discussion_comment.mark_discussion_started()

        prompt_path = discussion_comment.attachment_path(prompt_number)
        puts prompt_path

        error!({error: 'File missing'}, 404) unless File.exists? prompt_path
        logger.info("#{current_user.username} - get discussion comment for task #{task.id} (#{task_definition.abbreviation})")

        env['api.format'] = :binary

        # mark as attachment
        if params[:as_attachment]
          header['Content-Disposition'] = "attachment; filename=#{prompt_path}"
        end

        # Work out what part to return
        file_size = File.size(prompt_path)
        begin_point = 0
        end_point = file_size - 1

        # Was it asked for just a part of the file?
        if request.headers['Range']
          # indicate partial content
          status 206

          # extract part desired from the content
          if request.headers['Range'] =~ /bytes\=(\d+)\-(\d*)/
            begin_point = $1.to_i
            end_point = $2.to_i if $2.present?
          end

          end_point = file_size - 1 unless end_point < file_size - 1
        end

        # Return the requested content
        content_length = end_point - begin_point + 1
        header['Content-Range'] = "bytes #{begin_point}-#{end_point}/#{file_size}"
        header['Content-Length'] = content_length.to_s
        header['Accept-Ranges'] = 'bytes'

        # Read the binary data and return
        result = IO.binread(prompt_path, content_length, begin_point)
        result
      end
    end

    desc 'Reply to a discussion comment of a task'
    params do
      requires :attachment, type: Rack::Multipart::UploadedFile, desc: 'discussion reply.'
    end
    post '/projects/:project_id/task_def_id/:task_definition_id/comments/:task_comment_id/discussion_comment/reply' do

      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :make_discussion_reply
        # error!({ error: 'Not authorised to reply to this discussion comment' }, 403)
      end

      attached_file = params[:attachment]

      if attached_file.present?
        error!(error: 'Attachment is empty.') unless File.size?(attached_file.tempfile.path).present?
        error!(error: 'Attachment exceeds the maximum attachment size of 30MB.') unless File.size?(attached_file.tempfile.path) < 30_000_000
      end

      task = project.task_for_task_definition(task_definition)
      # type_string = content_type.to_s

      logger.info("#{current_user.username} - added a reply to the discussion comment #{params[:discussion_comment_id]} for task #{task.id} (#{task_definition.abbreviation})")

      if attached_file.nil? || attached_file.empty?
        error!({ error: 'Discussion reply is empty, unable to add new reply to discussion comment' }, 403)
      end

      task_comment = task.all_comments.find(params[:task_comment_id])
      discussion_comment = task_comment.discussion_comment

      error!({ error: 'No discussion comment found for the given task' }, 403)

      result = discussion_comment.add_reply(current_user, attached_file)
      discussion_comment.finishDiscussion
    end
  end
end
