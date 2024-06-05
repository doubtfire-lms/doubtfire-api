require 'grape'

class ScormExtensionCommentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  desc 'Request a scorm extension for a task'
  params do
    requires :comment, type: String, desc: 'The details of the request'
  end
  post '/projects/:project_id/task_def_id/:task_definition_id/request_scorm_extension' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    # check permissions using specific permission has with addition of request extension if allowed in unit
    unless authorise? current_user, task, :request_scorm_extension
      error!({ error: 'Not authorised to request a scorm extension for this task' }, 403)
    end

    result = task.apply_for_scorm_extension(current_user, params[:comment])
    present result.serialize(current_user), Grape::Presenters::Presenter
  end

  desc 'Assess a scorm extension for a task'
  params do
    requires :granted, type: Boolean, desc: 'Assess a scorm extension'
  end
  put '/projects/:project_id/task_def_id/:task_definition_id/assess_scorm_extension/:task_comment_id' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    unless authorise? current_user, task, :assess_scorm_extension
      error!({ error: 'Not authorised to assess a scorm extension for this task' }, 403)
    end

    task_comment = task.all_comments.find(params[:task_comment_id]).becomes(ScormExtensionComment)

    unless task_comment.assess_scorm_extension(current_user, params[:granted])
      if task_comment.errors.count >= 1
        error!({ error: task_comment.errors.full_messages.first }, 403)
      else
        error!({ error: 'Error saving scorm extension' }, 403)
      end
    end
    present task_comment.serialize(current_user), Grape::Presenters::Presenter
  end
end
