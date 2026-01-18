require 'grape'

class ExtensionCommentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  desc 'Request an extension for a task'
  params do
    requires :comment, type: String, desc: 'The details of the request'
    requires :weeks_requested, type: Integer, desc: 'The details of the request'
  end
  post '/projects/:project_id/task_def_id/:task_definition_id/request_extension' do
    # Use the ExtensionService to handle the extension request
    result = ExtensionService.grant_extension(
      params[:project_id],
      params[:task_definition_id],
      current_user,
      params[:weeks_requested],
      params[:comment]
    )

    # Handle the service response
    if result[:success]
      present result[:result].serialize(current_user), Grape::Presenters::Presenter
    else
      error!({ error: result[:error] }, result[:status])
    end
=begin
    if project.unit.allow_flexible_dates
      error!({ error: 'Extensions are disabled for this unit.' }, 403)
    end

    error!({ error: 'Extension weeks can not be 0.' }, 403) if params[:weeks_requested] == 0

    max_duration = task.weeks_can_extend
    duration = params[:weeks_requested]
    duration = max_duration unless params[:weeks_requested] <= max_duration

    error!({ error: 'Extensions cannot be granted beyond task deadline.' }, 403) if duration <= 0

    result = task.apply_for_extension(current_user, params[:comment], duration)
    present result.serialize(current_user), Grape::Presenters::Presenter
=end
  end

  desc 'Assess an extension for a task'
  params do
    requires :granted, type: Boolean, desc: 'Assess an extension'
  end
  put '/projects/:project_id/task_def_id/:task_definition_id/assess_extension/:task_comment_id' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    unless authorise? current_user, task, :assess_extension
      error!({ error: 'Not authorised to assess an extension for this task' }, 403)
    end

    task_comment = task.all_comments.find(params[:task_comment_id]).becomes(ExtensionComment)

    unless task_comment.assess_extension(current_user, params[:granted])
      if task_comment.errors.count >= 1
        error!({ error: task_comment.errors.full_messages.first }, 403)
      else
        error!({ error: 'Error saving extension' }, 403)
      end
    end
    present task_comment.serialize(current_user), Grape::Presenters::Presenter
  end
end
