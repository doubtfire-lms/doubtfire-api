require 'grape'

class SubmissionCommentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  desc 'Request early submission access for a task'
  params do
    requires :comment, type: String, desc: 'The reason for requesting submission access'
  end
  post '/projects/:project_id/task_def_id/:task_definition_id/request_submission_access' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    unless authorise? current_user, task, :request_submission_access
      error!({ error: 'Not authorised to request submission access for this task' }, 403)
    end

    error!({ error: 'Submission access request reason cannot be blank' }, 400) if params[:comment].blank?

    result = task.with_lock do
      unless task.can_apply_for_submission_access?
        error!({ error: task.submission_access_request_error }, 409)
      end
      task.apply_for_submission_access(current_user, params[:comment])
    end
    present result.serialize(current_user), Grape::Presenters::Presenter
  end

  desc 'Assess a submission access request for a task'
  params do
    requires :granted, type: Boolean, desc: 'Whether submission access is granted'
  end
  put '/projects/:project_id/task_def_id/:task_definition_id/assess_submission_access/:task_comment_id' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    unless authorise? current_user, task, :assess_submission_access
      error!({ error: 'Not authorised to assess submission access for this task' }, 403)
    end

    task_comment = task.all_comments.find(params[:task_comment_id]).becomes(SubmissionComment)

    unless task_comment.assess_submission_access(current_user, params[:granted])
      if task_comment.errors.count >= 1
        error!({ error: task_comment.errors.full_messages.first }, 403)
      else
        error!({ error: 'Error saving submission access request' }, 403)
      end
    end

    present task_comment.serialize(current_user), Grape::Presenters::Presenter
  end
end
