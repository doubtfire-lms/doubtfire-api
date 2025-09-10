require 'grape'

class TaskPrerequisitesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Get task prerequisites for a task definition'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to get the task definition from'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the prerequisites for'
  end
  get '/units/:unit_id/task_definitions/:task_def_id/prerequisites' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    prerequisites = task_def.task_prerequisites
    present prerequisites, with: Entities::TaskPrerequisiteEntity
  end

end
