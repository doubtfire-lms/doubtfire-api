class TaskChannel < ApplicationCable::Channel
  include AuthorisationHelpers

  def subscribed
    project = Project.find_by(id: params[:project_id])
    task_definition = project&.unit&.task_definitions&.find_by(id: params[:task_definition_id])

    return reject unless project && task_definition && authorise?(current_user, project, :get)
    return reject unless project.has_task_for_task_definition?(task_definition)

    stream_for project.task_for_task_definition(task_definition)
  end
end
