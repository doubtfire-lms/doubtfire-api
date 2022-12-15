require 'grape'

class StageApi < Grape::API

  desc 'Create a new stage'
  params do
    requires :task_definition_id, type: Integer, desc: 'The task definition to which the stage belongs'
    requires :title, type: String,  desc: 'The title of the new stage'
    requires :order, type: Integer, desc: 'The order to determine the order in which to display stages'
  end
  post '/stages' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition.unit, :update
      error!({ error: 'Not authorised to create a stage for this unit' }, 403)
    end

    stage_parameters = ActionController::Parameters.new(params)
      .permit(:title, :order)

    stage_parameters[:task_definition] = task_definition

    result = Stage.create!(stage_parameters)

    present result, with: Entities::StageEntity
  end

  get '/stages' do
    present Stage.all, with: Entities::StageEntity
  end

end
