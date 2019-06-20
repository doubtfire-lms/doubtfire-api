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
      result.serialize(current_user)
    end

    desc 'Get a discussion comment on a task comment'
    get '/projects/:project_id/task_def_id/:task_definition_id/comments/:task_comment_id/discussion_comment' do
      project = Project.find(params[:project_id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      # unless authorise? current_user, project, :get_discussion
      #   error!({ error: 'You cannot get this discussion' }, 403)
      # end

      task = project.task_for_task_definition(task_definition)
      task_comment = task.all_comments.find(params[:id])
      task_comment.discussion_comment
    end
  end
end
