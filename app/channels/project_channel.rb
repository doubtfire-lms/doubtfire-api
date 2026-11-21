class ProjectChannel < ApplicationCable::Channel
  include AuthorisationHelpers

  def self.stream_name(project_id)
    "project:#{project_id}"
  end

  def subscribed
    project = Project.find_by(id: params[:project_id])

    return reject unless project && authorise?(current_user, project, :get)

    stream_from self.class.stream_name(project.id)
  end
end
