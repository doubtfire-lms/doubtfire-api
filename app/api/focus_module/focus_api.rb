require 'grape'

module FocusModule

  class FocusApi < ApplicationAuthenticatedApi

    desc 'Get focuses associated with a unit'
    get '/units/:unit_id/focuses' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :get_unit
        error!({ error: 'Not authorised to access the focuses of this unit' }, 403)
      end

      focuses = unit.focuses.order('title ASC')
      present focuses, with: Entities::FocusEntity
    end

    desc 'Create a focus in a unit'
    params do
      requires :title,        type: String,  desc: 'The title for the focus'
      requires :description,  type: String,  desc: 'The description for the focus'
      requires :color,        type: String,  desc: 'The color for the focus'
    end
    post '/units/:unit_id/focuses' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to add focuses to this unit' }, 403)
      end

      focus_params = ActionController::Parameters.new(params)
                      .permit(
                        :title,
                        :description,
                        :color
                      )

      focus_params[:unit_id] = unit.id

      result = Focus.create!(focus_params)
      present result, with: Entities::FocusEntity
    end

    desc 'Update a focus in a unit'
    params do
      optional :title,        type: String,  desc: 'The title for the focus'
      optional :description,  type: String,  desc: 'The description for the focus'
      optional :color,        type: String,  desc: 'The color for the focus'
    end
    put '/units/:unit_id/focuses/:focus_id' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update focuses in this unit' }, 403)
      end

      focus_params = ActionController::Parameters.new(params)
                      .permit(
                        :title,
                        :description,
                        :color
                      )

      focus = unit.focuses.find(params[:focus_id])

      focus.update!(focus_params)
      present focus, with: Entities::FocusEntity
    end

    desc 'Delete a focus in a unit'
    delete '/units/:unit_id/focuses/:focus_id' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to delete focuses in this unit' }, 403)
      end

      focus = unit.focuses.find(params[:focus_id])

      focus.destroy!
      present true, with: Grape::Presenters::Presenter
    end

    desc 'Set a grade criteria for a focus'
    params do
      requires :criteria, type: String, desc: 'The criteria for the indicated grade for the focus'
      requires :grade, type: Integer, desc: 'The grade for the focus criteria'
    end
    put '/units/:unit_id/focuses/:focus_id/criteria/:grade' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update the grade criteria for this focus' }, 403)
      end

      unless (GradeHelper::RANGE) === params[:grade]
        error!({error: 'Grade is invalid'}, 403)
      end

      focus = Focus.find(params[:focus_id])

      focus.set_criteria(params[:grade], params[:criteria])
      focus.save!

      present focus, with: Entities::FocusEntity
    end

    desc 'Add a focus to a task definition'
    params do
      requires :focus_id, type: Integer, desc: 'The focus to add to the task definition'
    end
    post '/units/:unit_id/task_definitions/:task_definition_id/focuses' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to add focuses to this unit' }, 403)
      end

      task_definition = unit.task_definitions.find(params[:task_definition_id])

      focus = unit.focuses.find(params[:focus_id])

      task_definition.add_focus(focus)

      present task_definition.task_definition_required_focuses, with: Entities::TaskDefinitionRequiredFocusEntity
    end

    desc 'Remove a focus from a task definition'
    params do
      requires :focus_id, type: Integer, desc: 'The focus to add to the task definition'
    end
    delete '/units/:unit_id/task_definitions/:task_definition_id/focuses/:focus_id' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to add focuses to this unit' }, 403)
      end

      task_definition = unit.task_definitions.find(params[:task_definition_id])

      focus = unit.focuses.find(params[:focus_id])

      task_definition.remove_focus(focus)

      present task_definition.task_definition_required_focuses, with: Entities::TaskDefinitionRequiredFocusEntity
    end

  end
end
