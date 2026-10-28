class TaskChannel < ApplicationCable::Channel
  include AuthorisationHelpers

  # Keyed by project and task definition so clients can subscribe before the task record exists
  def self.stream_name(project_id, task_definition_id)
    "task:#{project_id}:#{task_definition_id}"
  end

  # A failed broadcast must not fail the request or job that changed the task
  def self.broadcast_event(task, event)
    ActionCable.server.broadcast(stream_name(task.project_id, task.task_definition_id), { event: event })
  rescue StandardError => e
    Rails.logger.error("TaskChannel #{event} broadcast failed for task #{task.id}: #{e.message}")
  end

  def subscribed
    project = Project.find_by(id: params[:project_id])
    task_definition = project&.unit&.task_definitions&.find_by(id: params[:task_definition_id])

    return reject unless task_definition && authorise?(current_user, project, :get)

    stream_from self.class.stream_name(project.id, task_definition.id)
  end
end
