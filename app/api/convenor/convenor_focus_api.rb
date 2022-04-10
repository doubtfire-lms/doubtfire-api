require 'grape'

module Convenor

  class ConvenorFocusApi < ApplicationAuthenticatedApi

    desc 'Get focuses associated with a unit'
    get '/unit/:unit_id/focuses' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :get_unit
        error!({ error: 'Not authorised to access the focuses of this unit' }, 403)
      end

      focuses = unit.focuses.order('title ASC')
      present focuses, with: Entities::FocusEntity
    end


    desc 'Create a focus in a unit'
    params do
      requires :focus, type: Hash do
        requires :title,        type: String,  desc: 'The title for the focus'
        requires :description,  type: String,  desc: 'The description for the focus'
        requires :color,        type: String,  desc: 'The color for the focus'
      end
    end
    post '/unit/:unit_id/focuses' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to add focuses to this unit' }, 403)
      end

      focus_params = ActionController::Parameters.new(params)
                      .require(:focus)
                      .permit(
                        :title,
                        :description,
                        :color
                      )

      focus_params[:unit_id] = unit.id

      result = Focus.create!(focus_params)
      present result, with: Entities::FocusEntity
    end

    desc 'Set a grade criteria for a focus'
    params do
      requires :criteria, type: String, desc: 'The criteria for the indicated grade for the focus'
    end
    put '/unit/:unit_id/focuses/:focus_id/grade_criteria/:grade' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update the grade criteria for this focus' }, 403)
      end

      focus = Focus.find(params[:focus_id])

      focus.set_grade_criteria(params[:grade], params[:criteria])
      focus.save!

      present focus, with: Entities::FocusEntity
    end

  end
end
